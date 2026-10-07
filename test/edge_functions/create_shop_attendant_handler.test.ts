// Tests for supabase/functions/create-shop-attendant/handler.ts with fake
// dependencies. Run with Node 22.18+ (TypeScript types are stripped):
//   node --test test/edge_functions/create_shop_attendant_handler.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  createHandler,
  parseAttendantInput,
  type AttachedMember,
  type CreatedAuthUser,
  type Dependencies,
  type OwnerShop,
} from '../../supabase/functions/create-shop-attendant/handler.ts';

const ownerToken = 'owner-token';
const ownerId = 'owner-1';
const password = 'Temp-Pass-123';

interface Fake extends Dependencies {
  calls: string[];
  created: Array<{ email: string; password: string; displayName: string }>;
}

function fakeDeps(overrides: {
  owners?: Record<string, string>;
  /** Replaces the owner lookup result, or throws this error from it. */
  ownerShop?: OwnerShop | Error;
  create?: CreatedAuthUser;
  /** Replaces the membership result, or throws this error from it. */
  attach?: AttachedMember | Error;
  /** false: cleanup reports failure; an Error: cleanup throws it. */
  deleteResult?: boolean | Error;
  confirmation?: boolean;
} = {}): Fake {
  const owners = overrides.owners ?? { [ownerId]: 'shop-a' };
  const calls: string[] = [];
  const created: Fake['created'] = [];
  return {
    calls,
    created,
    async getCallerId(token) {
      calls.push(`caller:${token}`);
      return token === ownerToken ? ownerId : token === 'staff-token' ? 'staff-1' : null;
    },
    async getOwnerShop(userId) {
      calls.push(`owner-shop:${userId}`);
      if (overrides.ownerShop instanceof Error) throw overrides.ownerShop;
      if (overrides.ownerShop) return overrides.ownerShop;
      const shopId = owners[userId];
      return shopId ? { ok: true, shopId } : { ok: false, reason: 'not_owner' };
    },
    async createAuthUser(input) {
      calls.push(`create:${input.email}`);
      created.push(input);
      return overrides.create ?? { ok: true, userId: 'new-user' };
    },
    async attachMember(owner, member) {
      calls.push(`attach:${owner}:${member}`);
      if (overrides.attach instanceof Error) throw overrides.attach;
      return overrides.attach ?? { ok: true, memberId: 'm-1', role: 'staff', status: 'active' };
    },
    async deleteAuthUser(userId) {
      calls.push(`delete:${userId}`);
      if (overrides.deleteResult instanceof Error) throw overrides.deleteResult;
      return overrides.deleteResult ?? true;
    },
    async sendConfirmationEmail(email) {
      calls.push(`confirm:${email}`);
      return overrides.confirmation ?? true;
    },
  };
}

function post(body: unknown, token: string | null = ownerToken): Request {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token !== null) headers['Authorization'] = `Bearer ${token}`;
  return new Request('http://localhost/create-shop-attendant', {
    method: 'POST',
    headers,
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

const validBody = {
  email: '  Esi.Mensah@Example.COM ',
  display_name: '  Esi Mensah ',
  temporary_password: password,
};

async function read(response: Response): Promise<Record<string, unknown>> {
  return (await response.json()) as Record<string, unknown>;
}

test('creates a staff login for the caller\'s shop and normalizes the input', async () => {
  const deps = fakeDeps();
  const response = await createHandler(deps)(post(validBody));

  assert.equal(response.status, 201);
  const body = await read(response);
  assert.deepEqual(body, {
    user_id: 'new-user',
    email: 'esi.mensah@example.com',
    display_name: 'Esi Mensah',
    role: 'staff',
    status: 'active',
    confirmation_email_sent: true,
  });
  assert.deepEqual(deps.created, [
    { email: 'esi.mensah@example.com', password, displayName: 'Esi Mensah' },
  ]);
  assert.deepEqual(deps.calls, [
    `caller:${ownerToken}`,
    `owner-shop:${ownerId}`,
    'create:esi.mensah@example.com',
    `attach:${ownerId}:new-user`,
    'confirm:esi.mensah@example.com',
  ]);
});

test('never returns the temporary password', async () => {
  const response = await createHandler(fakeDeps())(post(validBody));
  const text = await response.text();
  assert.ok(!text.includes(password));
});

test('shop, role and owner in the body are ignored', async () => {
  const deps = fakeDeps();
  const response = await createHandler(deps)(post({
    ...validBody,
    shop_id: 'someone-elses-shop',
    role: 'owner',
    owner_user_id: 'other-owner',
    p_shop_id: 'x',
  }));

  assert.equal(response.status, 201);
  assert.equal((await read(response)).role, 'staff');
  // The membership is attached for the token's user, nobody else.
  assert.ok(deps.calls.includes(`attach:${ownerId}:new-user`));
  assert.ok(!deps.calls.some((call) => call.includes('other-owner')));
});

test('missing or invalid token: 401 and nothing created', async () => {
  for (const token of [null, 'forged-token']) {
    const deps = fakeDeps();
    const response = await createHandler(deps)(post(validBody, token));
    assert.equal(response.status, 401);
    assert.ok(!deps.calls.some((call) => call.startsWith('create')));
  }
});

test('a non-owner (e.g. staff): 403 before any account is created', async () => {
  const deps = fakeDeps();
  const response = await createHandler(deps)(post(validBody, 'staff-token'));

  assert.equal(response.status, 403);
  assert.equal(((await read(response)).error as { code: string }).code, 'not_owner');
  assert.deepEqual(deps.calls, ['caller:staff-token', 'owner-shop:staff-1']);
});

test('invalid input: 400 and no account, no owner lookup', async () => {
  const cases: Array<[unknown, string]> = [
    [{ ...validBody, email: 'not-an-email' }, 'invalid_email'],
    [{ ...validBody, email: 42 }, 'invalid_email'],
    [{ ...validBody, display_name: '   ' }, 'invalid_name'],
    [{ ...validBody, display_name: 'a'.repeat(81) }, 'invalid_name'],
    [{ ...validBody, display_name: 'Esi\nMensah' }, 'invalid_name'],
    [{ ...validBody, temporary_password: 'short' }, 'invalid_password'],
    [{ ...validBody, temporary_password: 'x'.repeat(73) }, 'invalid_password'],
    [{ ...validBody, temporary_password: '          ' }, 'invalid_password'],
    [{ ...validBody, temporary_password: 'esi.mensah@example.com' }, 'invalid_password'],
    [{ email: validBody.email }, 'invalid_name'],
    [[], 'invalid_request'],
    ['{not json', 'invalid_request'],
  ];
  for (const [body, code] of cases) {
    const deps = fakeDeps();
    const response = await createHandler(deps)(post(body));
    assert.equal(response.status, 400, JSON.stringify(body));
    assert.equal(((await read(response)).error as { code: string }).code, code);
    assert.ok(!deps.calls.some((call) => call.startsWith('create')));
  }
});

test('an email that already has an account: 409, nothing attached', async () => {
  const deps = fakeDeps({ create: { ok: false, reason: 'email_exists' } });
  const response = await createHandler(deps)(post(validBody));

  assert.equal(response.status, 409);
  const error = (await read(response)).error as { code: string; message: string };
  assert.equal(error.code, 'email_exists');
  assert.equal(error.message, 'This email already has a ShopMate account.');
  assert.ok(!deps.calls.some((call) => call.startsWith('attach')));
});

test('membership failure deletes the new login (no orphan account)', async () => {
  for (const reason of ['failed', 'already_member'] as const) {
    const deps = fakeDeps({ attach: { ok: false, reason } });
    const response = await createHandler(deps)(post(validBody));
    assert.equal(response.status, 500);
    assert.ok(deps.calls.includes('delete:new-user'));
    assert.ok(!deps.calls.some((call) => call.startsWith('confirm')));
  }
});

test('owner lost access mid-request: 403 and the new login is deleted', async () => {
  const deps = fakeDeps({ attach: { ok: false, reason: 'not_owner' } });
  const response = await createHandler(deps)(post(validBody));

  assert.equal(response.status, 403);
  assert.ok(deps.calls.includes('delete:new-user'));
});

test('membership step throwing still deletes the new login', async () => {
  const deps = fakeDeps({
    attach: new Error('connection terminated: relation shop_members, sqlstate 08006'),
  });
  const response = await createHandler(deps)(post(validBody));

  assert.equal(response.status, 500);
  const text = await response.text();
  assert.ok(!text.includes('sqlstate'));
  assert.ok(!text.includes('shop_members'));
  assert.ok(!text.includes(password));
  assert.equal(JSON.parse(text).error.code, 'create_failed');
  // Only this request's new user is deleted, exactly once, and no
  // confirmation email goes out.
  assert.deepEqual(deps.calls.filter((call) => call.startsWith('delete')), ['delete:new-user']);
  assert.ok(!deps.calls.some((call) => call.startsWith('confirm')));
});

test('a failed or throwing cleanup exposes nothing and is not retried', async () => {
  const internal = 'AuthApiError: service_role key rejected for user new-user';
  const cases: Array<[AttachedMember | Error, boolean | Error, number]> = [
    [{ ok: false, reason: 'failed' }, false, 500],
    [{ ok: false, reason: 'failed' }, new Error(internal), 500],
    [new Error('membership exploded'), new Error(internal), 500],
    [{ ok: false, reason: 'not_owner' }, new Error(internal), 403],
  ];
  for (const [attach, deleteResult, status] of cases) {
    const deps = fakeDeps({ attach, deleteResult });
    const response = await createHandler(deps)(post(validBody));

    assert.equal(response.status, status);
    const text = await response.text();
    const body = JSON.parse(text) as { error: { code: string; message: string } };
    assert.deepEqual(Object.keys(body), ['error']);
    assert.ok(!text.includes('AuthApiError'));
    assert.ok(!text.includes('service_role'));
    assert.ok(!text.includes('exploded'));
    assert.ok(!text.includes('new-user'));
    assert.ok(!text.includes(password));
    assert.equal(deps.calls.filter((call) => call.startsWith('delete')).length, 1);
  }
});

test('owner check failing: safe 500, not a 403, and nothing created', async () => {
  const failures: Array<OwnerShop | Error> = [
    { ok: false, reason: 'failed' },
    new Error('permission denied for function shop_attendant_owner_shop (SQLSTATE 42883)'),
  ];
  for (const ownerShop of failures) {
    const deps = fakeDeps({ ownerShop });
    const response = await createHandler(deps)(post(validBody));

    assert.equal(response.status, 500);
    const text = await response.text();
    const error = (JSON.parse(text) as { error: { code: string; message: string } }).error;
    assert.equal(error.code, 'server_error');
    assert.equal(error.message, 'Something went wrong. Try again.');
    assert.ok(!text.includes('Only the shop owner'));
    assert.ok(!text.includes('SQLSTATE'));
    assert.ok(!text.includes('shop_attendant_owner_shop'));
    assert.deepEqual(deps.calls, [`caller:${ownerToken}`, `owner-shop:${ownerId}`]);
  }
});

test('a caller with no active shop: 403 not_owner, nothing created', async () => {
  const deps = fakeDeps({ owners: {} });
  const response = await createHandler(deps)(post(validBody));

  assert.equal(response.status, 403);
  const error = (await read(response)).error as { code: string; message: string };
  assert.equal(error.code, 'not_owner');
  assert.equal(error.message, 'Only the shop owner can add attendants.');
  assert.ok(!deps.calls.some((call) => call.startsWith('create')));
});

test('a failed confirmation email still reports success', async () => {
  const deps = fakeDeps({ confirmation: false });
  const response = await createHandler(deps)(post(validBody));

  assert.equal(response.status, 201);
  assert.equal((await read(response)).confirmation_email_sent, false);
});

test('other Auth failures map to safe messages', async () => {
  const expected: Array<[CreatedAuthUser, number, string]> = [
    [{ ok: false, reason: 'weak_password' }, 400, 'weak_password'],
    [{ ok: false, reason: 'invalid_email' }, 400, 'invalid_email'],
    [{ ok: false, reason: 'failed' }, 500, 'create_failed'],
  ];
  for (const [create, status, code] of expected) {
    const response = await createHandler(fakeDeps({ create }))(post(validBody));
    assert.equal(response.status, status);
    assert.equal(((await read(response)).error as { code: string }).code, code);
  }
});

test('only POST (and CORS preflight) are accepted', async () => {
  const handler = createHandler(fakeDeps());
  const preflight = await handler(new Request('http://localhost/x', { method: 'OPTIONS' }));
  assert.equal(preflight.status, 204);
  const get = await handler(new Request('http://localhost/x', { method: 'GET' }));
  assert.equal(get.status, 405);
});

test('parseAttendantInput accepts a valid body', () => {
  const parsed = parseAttendantInput({
    email: 'A@B.CO',
    display_name: 'Kofi',
    temporary_password: 'abcdefgh',
  });
  assert.deepEqual(parsed, {
    ok: true,
    value: { email: 'a@b.co', displayName: 'Kofi', temporaryPassword: 'abcdefgh' },
  });
});
