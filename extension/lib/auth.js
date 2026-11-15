// Firebase sign-in over plain HTTPS (no SDK needed in the extension).
import { API_KEY } from './config.js';

const IDT = 'https://identitytoolkit.googleapis.com/v1';
const store = chrome.storage.local;

const MESSAGES = {
  INVALID_LOGIN_CREDENTIALS: 'Wrong email or password.',
  INVALID_PASSWORD: 'Wrong email or password.',
  EMAIL_NOT_FOUND: 'No account with that email. Make one in the app first.',
  USER_DISABLED: 'This account is switched off.',
  TOO_MANY_ATTEMPTS_TRY_LATER: 'Too many tries. Wait a minute and try again.',
  INVALID_EMAIL: 'That email doesn’t look right.',
  MISSING_PASSWORD: 'Type your password.',
  TOKEN_EXPIRED: 'Please sign in again.',
  INVALID_REFRESH_TOKEN: 'Please sign in again.',
};

export class AuthError extends Error {}

function friendly(code) {
  const key = String(code || '').split(' ')[0].split(':')[0];
  return MESSAGES[key] || 'Couldn’t sign in. Check your internet and try again.';
}

async function post(url, body, form = false) {
  let r;
  try {
    r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': form ? 'application/x-www-form-urlencoded' : 'application/json' },
      body: form ? new URLSearchParams(body).toString() : JSON.stringify(body),
    });
  } catch {
    throw new AuthError('No internet connection.');
  }
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new AuthError(friendly(j?.error?.message));
  return j;
}

async function verified(idToken) {
  const j = await post(`${IDT}/accounts:lookup?key=${API_KEY}`, { idToken });
  const u = (j.users || [])[0] || {};
  return { emailVerified: !!u.emailVerified, name: u.displayName || '' };
}

async function keep(s) {
  await store.set({ session: s });
  return s;
}

export async function signInWithEmail(email, password) {
  const j = await post(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, { email: email.trim(), password, returnSecureToken: true });
  const v = await verified(j.idToken);
  if (!v.emailVerified) throw new AuthError('Confirm your email first. Open the link we sent you, then try again.');
  return keep({ email: j.email.toLowerCase(), name: v.name || j.displayName || '', idToken: j.idToken, refreshToken: j.refreshToken, exp: Date.now() + (Number(j.expiresIn) - 60) * 1000 });
}

/// Google sign-in happens on the website (Firebase popup). It hands us a refresh token.
export async function signInWithRefreshToken(refreshToken) {
  const s = await refresh({ refreshToken });
  const v = await verified(s.idToken);
  if (!v.emailVerified) throw new AuthError('Confirm your email first.');
  return keep({ ...s, name: v.name || s.name || '' });
}

async function refresh(s) {
  const j = await post(`https://securetoken.googleapis.com/v1/token?key=${API_KEY}`, { grant_type: 'refresh_token', refresh_token: s.refreshToken }, true);
  const email = s.email || JSON.parse(atob(j.id_token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))).email;
  return { ...s, email: String(email).toLowerCase(), idToken: j.id_token, refreshToken: j.refresh_token, exp: Date.now() + (Number(j.expires_in) - 60) * 1000 };
}

export async function session() {
  const { session: s } = await store.get('session');
  return s || null;
}

/// A valid ID token, refreshed when needed. Null when signed out.
export async function token() {
  const s = await session();
  if (!s) return null;
  if (Date.now() < s.exp) return s;
  try {
    return await keep(await refresh(s));
  } catch (e) {
    if (e instanceof AuthError && /sign in again/.test(e.message)) await signOut();
    throw e;
  }
}

export async function signOut() {
  await store.remove(['session', 'cache']);
}
