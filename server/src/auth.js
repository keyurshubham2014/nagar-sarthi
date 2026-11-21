// Demo sign-in: phone + a fixed code from config, HMAC-signed session tokens (no new dependency).
import crypto from 'node:crypto';
import { config, authSecret } from './config.js';
import { pool } from './db.js';
import { ApiError } from './errors.js';

const TTL_MS = 12 * 60 * 60 * 1000;
// One demo user per role, all in ward E. Any other valid phone signs in as a citizen.
const SEED = { '9000000001': 'citizen', '9000000002': 'corporator', '9000000003': 'officer' };
const SEED_WARD = 'E';

export async function seedUsers() {
  for (const [phone, role] of Object.entries(SEED)) {
    await pool.query('INSERT INTO users (phone, role, ward_code) VALUES ($1, $2, $3) ON CONFLICT (phone) DO NOTHING', [phone, role, SEED_WARD]);
  }
}

const mac = (payload) => crypto.createHmac('sha256', authSecret()).update(payload).digest();
const same = (a, b) => a.length === b.length && crypto.timingSafeEqual(a, b);

function issue(claims) {
  const payload = Buffer.from(JSON.stringify({ ...claims, exp: Date.now() + TTL_MS })).toString('base64url');
  return `${payload}.${mac(payload).toString('base64url')}`;
}

/** Claims {uid, role, ward_code, exp} for a valid, unexpired token; otherwise null. */
export function verify(token) {
  const [payload, sig, extra] = String(token).split('.');
  if (!payload || !sig || extra !== undefined || !same(Buffer.from(sig, 'base64url'), mac(payload))) return null;
  try {
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString());
    return typeof claims.exp === 'number' && claims.exp > Date.now() ? claims : null;
  } catch {
    return null;
  }
}

const invalid = (fields) => new ApiError(400, 'validation_failed', 'Please correct the highlighted fields', fields);

export async function login(b) {
  const phone = typeof b.phone === 'string' ? b.phone.replace(/[\s-]/g, '') : '';
  const code = typeof b.code === 'string' ? b.code.trim() : '';
  const fields = {};
  if (!/^\d{10}$/.test(phone)) fields.phone = 'Enter a 10-digit mobile number';
  if (!code) fields.code = 'Enter the code';
  if (Object.keys(fields).length) throw invalid(fields);
  // Compare hashes so the comparison time does not depend on the code.
  const h = (s) => crypto.createHash('sha256').update(s).digest();
  if (!same(h(code), h(config.demoLoginCode))) throw new ApiError(401, 'invalid_code', 'That code is not right. Check it and try again.');

  let user;
  try {
    const { rows } = await pool.query(
      `INSERT INTO users (phone, role, ward_code) VALUES ($1, $2, $3)
       ON CONFLICT (phone) DO UPDATE SET phone = EXCLUDED.phone RETURNING id, role, ward_code`,
      [phone, SEED[phone] ?? 'citizen', SEED[phone] ? SEED_WARD : null],
    );
    user = rows[0];
  } catch (e) {
    // Postgres down: still let the demo users in (read views and Claude drafts work without it).
    console.warn('[auth] users table unavailable:', e.code ?? e.message);
    user = { id: null, role: SEED[phone] ?? 'citizen', ward_code: SEED[phone] ? SEED_WARD : null };
  }
  const token = issue({ uid: user.id, role: user.role, ward_code: user.ward_code });
  return { token, role: user.role, ward_code: user.ward_code, phone };
}

/** Middleware: sets req.user from a valid Bearer token; never rejects (routes decide). */
export function session(req, _res, next) {
  const h = req.get('authorization');
  req.user = h?.startsWith('Bearer ') ? verify(h.slice(7)) : null;
  next();
}

export function needUser(req, what = 'do this') {
  if (!req.user) throw new ApiError(401, 'unauthorized', `Sign in to ${what}.`);
  return req.user;
}

export function needRole(req, role, what) {
  if (needUser(req, what).role !== role) throw new ApiError(403, 'forbidden', `Only a ward ${role} can ${what}.`);
}
