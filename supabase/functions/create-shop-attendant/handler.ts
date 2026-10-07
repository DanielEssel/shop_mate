// create-shop-attendant: request handling, independent of Supabase so it can
// be tested with fakes. index.ts wires the real Supabase clients.
//
// Trust model: the caller is identified ONLY from their verified access
// token. The shop and the role are derived on the server (the database
// helpers re-check the owner); the request body supplies just the new
// attendant's email, display name and temporary password. Any shop_id,
// role or user id in the body is ignored.
//
// The temporary password is passed straight to Supabase Auth and is never
// stored, logged or returned.

export type CreatedAuthUser =
  | { ok: true; userId: string }
  | { ok: false; reason: 'email_exists' | 'invalid_email' | 'weak_password' | 'failed' };

/** The owner check: refused (not an active owner of an active shop) is
 * different from the check itself failing. */
export type OwnerShop =
  | { ok: true; shopId: string }
  | { ok: false; reason: 'not_owner' | 'failed' };

export type AttachedMember =
  | { ok: true; memberId: string; role: string; status: string }
  | { ok: false; reason: 'not_owner' | 'already_member' | 'failed' };

export interface Dependencies {
  /** The user id in a valid access token, or null. */
  getCallerId(accessToken: string): Promise<string | null>;
  /** The caller's shop when they are an active owner of an active shop. */
  getOwnerShop(ownerUserId: string): Promise<OwnerShop>;
  createAuthUser(input: {
    email: string;
    password: string;
    displayName: string;
  }): Promise<CreatedAuthUser>;
  /** Adds the new user to the owner's shop as active staff. */
  attachMember(ownerUserId: string, memberUserId: string): Promise<AttachedMember>;
  deleteAuthUser(userId: string): Promise<boolean>;
  /** Sends the standard sign-up confirmation email; false if it failed. */
  sendConfirmationEmail(email: string): Promise<boolean>;
}

export interface AttendantInput {
  email: string;
  displayName: string;
  temporaryPassword: string;
}

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@.]{2,}$/;
const maxEmailLength = 254;
const maxNameLength = 80;
// Same policy as the app's sign-up; 72 bytes is the most the hash uses.
const minPasswordLength = 8;
const maxPasswordBytes = 72;

export type Parsed =
  | { ok: true; value: AttendantInput }
  | { ok: false; code: string; message: string };

/** Validates and normalizes the request body. */
export function parseAttendantInput(body: unknown): Parsed {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { ok: false, code: 'invalid_request', message: 'Invalid request.' };
  }
  const fields = body as Record<string, unknown>;

  const rawEmail = fields['email'];
  const rawName = fields['display_name'];
  const rawPassword = fields['temporary_password'];

  if (typeof rawEmail !== 'string') {
    return { ok: false, code: 'invalid_email', message: 'Enter a valid email address.' };
  }
  const email = rawEmail.trim().toLowerCase();
  if (email.length > maxEmailLength || !emailPattern.test(email)) {
    return { ok: false, code: 'invalid_email', message: 'Enter a valid email address.' };
  }

  if (typeof rawName !== 'string') {
    return { ok: false, code: 'invalid_name', message: 'Enter the attendant’s name.' };
  }
  const displayName = rawName.trim();
  // No control characters (newlines, tabs, ...) in a display label.
  if (
    displayName.length < 1 ||
    [...displayName].length > maxNameLength ||
    /[\u0000-\u001f\u007f]/.test(displayName)
  ) {
    return {
      ok: false,
      code: 'invalid_name',
      message: `Enter a name of 1 to ${maxNameLength} characters.`,
    };
  }

  if (typeof rawPassword !== 'string') {
    return {
      ok: false,
      code: 'invalid_password',
      message: `Use a temporary password of at least ${minPasswordLength} characters.`,
    };
  }
  const passwordBytes = new TextEncoder().encode(rawPassword).length;
  if (
    [...rawPassword].length < minPasswordLength ||
    passwordBytes > maxPasswordBytes ||
    rawPassword.trim().length === 0
  ) {
    return {
      ok: false,
      code: 'invalid_password',
      message: `Use a temporary password of ${minPasswordLength} to ${maxPasswordBytes} characters.`,
    };
  }
  if (rawPassword.trim().toLowerCase() === email) {
    return {
      ok: false,
      code: 'invalid_password',
      message: 'The temporary password cannot be the email address.',
    };
  }

  return { ok: true, value: { email, displayName, temporaryPassword: rawPassword } };
}

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function failure(status: number, code: string, message: string): Response {
  return json(status, { error: { code, message } });
}

export function createHandler(deps: Dependencies): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method !== 'POST') {
      return failure(405, 'method_not_allowed', 'Use POST.');
    }

    // 1. Who is calling: only a verified access token counts.
    const authorization = request.headers.get('Authorization') ?? '';
    const match = /^Bearer\s+(\S+)$/i.exec(authorization);
    const callerId = match ? await deps.getCallerId(match[1]) : null;
    if (callerId === null) {
      return failure(401, 'unauthorized', 'Sign in again to continue.');
    }

    // 2. What they asked for (email, name and temporary password only).
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return failure(400, 'invalid_request', 'Invalid request.');
    }
    const parsed = parseAttendantInput(body);
    if (!parsed.ok) {
      return failure(400, parsed.code, parsed.message);
    }
    const input = parsed.value;

    // 3. They must be an active owner of an active shop. Checked before any
    // account is created. A failed check is a server error, not a refusal.
    let ownerShop: OwnerShop;
    try {
      ownerShop = await deps.getOwnerShop(callerId);
    } catch {
      ownerShop = { ok: false, reason: 'failed' };
    }
    if (!ownerShop.ok) {
      return ownerShop.reason === 'not_owner'
        ? failure(403, 'not_owner', 'Only the shop owner can add attendants.')
        : failure(500, 'server_error', 'Something went wrong. Try again.');
    }

    // 4. Create the login.
    const created = await deps.createAuthUser({
      email: input.email,
      password: input.temporaryPassword,
      displayName: input.displayName,
    });
    if (!created.ok) {
      switch (created.reason) {
        case 'email_exists':
          return failure(409, 'email_exists', 'This email already has a ShopMate account.');
        case 'invalid_email':
          return failure(400, 'invalid_email', 'Enter a valid email address.');
        case 'weak_password':
          return failure(
            400,
            'weak_password',
            'Choose a stronger temporary password.',
          );
        default:
          return failure(500, 'create_failed', 'The account could not be created. Try again.');
      }
    }

    // 5. Add it to the owner's shop as staff. From here on the new login is
    // removed if the membership is not created, whether the step returns an
    // error or throws, so no orphan account is left behind. Only this
    // request's new user id is ever deleted.
    let member: AttachedMember;
    try {
      member = await deps.attachMember(callerId, created.userId);
    } catch {
      member = { ok: false, reason: 'failed' };
    }
    if (!member.ok) {
      try {
        await deps.deleteAuthUser(created.userId);
      } catch {
        // Nothing is logged or returned: the client gets the same safe
        // error either way.
      }
      if (member.reason === 'not_owner') {
        return failure(403, 'not_owner', 'Only the shop owner can add attendants.');
      }
      return failure(500, 'create_failed', 'The attendant could not be added. Try again.');
    }

    // 6. The account must confirm its email before signing in (project
    // policy). Best effort: the attendant can also resend from the sign-in
    // screen.
    const confirmationEmailSent = await deps.sendConfirmationEmail(input.email);

    return json(201, {
      user_id: created.userId,
      email: input.email,
      display_name: input.displayName,
      role: member.role,
      status: member.status,
      confirmation_email_sent: confirmationEmailSent,
    });
  };
}
