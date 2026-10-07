// create-shop-attendant Edge Function (Deno).
//
// Lets a shop owner create a login for a shop attendant. All checks live in
// handler.ts and in the database helpers it calls; this file only connects
// them to Supabase.
//
// Environment (provided by Supabase to every hosted Edge Function; nothing
// to set by hand, and never present in the app or the repository):
//   SUPABASE_URL
//   SUPABASE_ANON_KEY          - to send the confirmation email
//   SUPABASE_SERVICE_ROLE_KEY  - Auth Admin + service_role-only helpers
//
// Deploy with JWT verification on (the default), so only signed-in users
// reach it at all.

import { createClient } from 'npm:@supabase/supabase-js@2';

import { createHandler } from './handler.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL');
const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!supabaseUrl || !anonKey || !serviceRoleKey) {
  throw new Error('create-shop-attendant is missing its Supabase environment.');
}

const clientOptions = {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
};

// Server-side only. Never returned, logged or sent anywhere.
const admin = createClient(supabaseUrl, serviceRoleKey, clientOptions);
const publicClient = createClient(supabaseUrl, anonKey, clientOptions);

const handler = createHandler({
  async getCallerId(accessToken) {
    // Asks Supabase Auth to validate the token; a forged or expired token
    // returns an error.
    const { data, error } = await admin.auth.getUser(accessToken);
    return error || !data.user ? null : data.user.id;
  },

  async getOwnerShop(ownerUserId) {
    const { data, error } = await admin.rpc('shop_attendant_owner_shop', {
      p_owner_user_id: ownerUserId,
    });
    // 42501 is the helper's "not an active owner of an active shop"; any
    // other error means the check itself failed.
    if (error) {
      return { ok: false, reason: error.code === '42501' ? 'not_owner' : 'failed' };
    }
    return typeof data === 'string'
      ? { ok: true, shopId: data }
      : { ok: false, reason: 'failed' };
  },

  async createAuthUser({ email, password, displayName }) {
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      // Same rule as self sign-up: the address must be confirmed before the
      // account can sign in.
      email_confirm: false,
      // UI data only; access always comes from shop_members.
      user_metadata: { display_name: displayName, must_change_password: true },
    });
    if (!error && data.user) return { ok: true, userId: data.user.id };

    const code = error?.code;
    if (code === 'email_exists' || code === 'user_already_exists') {
      return { ok: false, reason: 'email_exists' };
    }
    if (code === 'email_address_invalid' || code === 'validation_failed') {
      return { ok: false, reason: 'invalid_email' };
    }
    if (code === 'weak_password') return { ok: false, reason: 'weak_password' };
    return { ok: false, reason: 'failed' };
  },

  async attachMember(ownerUserId, memberUserId) {
    const { data, error } = await admin.rpc('create_shop_attendant_membership', {
      p_owner_user_id: ownerUserId,
      p_member_user_id: memberUserId,
    });
    if (error) {
      if (error.code === '42501') return { ok: false, reason: 'not_owner' };
      if (error.code === '23505') return { ok: false, reason: 'already_member' };
      return { ok: false, reason: 'failed' };
    }
    const row = Array.isArray(data) ? data[0] : null;
    if (!row || typeof row.member_id !== 'string') return { ok: false, reason: 'failed' };
    return { ok: true, memberId: row.member_id, role: row.role, status: row.status };
  },

  async deleteAuthUser(userId) {
    // Only ever called for the account created moments ago in this request,
    // which has no history yet.
    const { error } = await admin.auth.admin.deleteUser(userId);
    return !error;
  },

  async sendConfirmationEmail(email) {
    const { error } = await publicClient.auth.resend({ type: 'signup', email });
    return !error;
  },
});

Deno.serve(handler);
