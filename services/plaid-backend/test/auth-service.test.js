import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';
import { AuthService } from '../src/auth-service.js';
import { LocalTokenCipher } from '../src/token-cipher.js';
import { ServiceError } from '../src/security.js';

let database, pool, service, identity, redeemed, validated, revokeGrant;
before(async () => {
  database = await temporaryPostgres(); pool = database.pool; await migrate(pool);
  service = new AuthService({ pool, cipher: new LocalTokenCipher(randomBytes(32)), allowedSubjects: ['fixture-owner'],
    apple: {
      async verify() { return identity; },
      async redeem() { return { identity: redeemed ?? identity, refreshToken: randomBytes(48).toString('base64url') }; },
      async validateGrant() { validated++; if (revokeGrant) throw new ServiceError('APPLE_GRANT_REVOKED', 401); },
    },
  });
});
after(async () => { await pool?.end(); await database?.stop(); });
beforeEach(async () => {
  await pool.query('TRUNCATE nomadfi.users, nomadfi.auth_challenges CASCADE');
  redeemed = null; validated = 0; revokeGrant = false;
});
async function login() {
  const challenge = await service.challenge();
  identity = { sub: 'fixture-owner', nonce: challenge.nonce };
  return service.login({ challengeID: challenge.challenge_id, identityToken: 'fixture-identity', authorizationCode: 'fixture-code' });
}

test('login stores hashed app credentials and encrypted Apple credentials', async () => {
  const tokens = await login();
  const session = await service.authenticate(tokens.access_token);
  assert.equal(session.user_id, tokens.user_id);
  const stored = (await pool.query('SELECT access_digest, refresh_digest FROM nomadfi.sessions')).rows[0];
  assert.equal(stored.access_digest.includes(Buffer.from(tokens.access_token)), false);
  assert.equal(stored.refresh_digest.includes(Buffer.from(tokens.refresh_token)), false);
  assert.equal((await pool.query('SELECT key_id FROM nomadfi.apple_grants')).rows[0].key_id, 'local-v1');
});

test('a login challenge is one-time and cannot be substituted or reused', async () => {
  const challenge = await service.challenge();
  const args = { challengeID: challenge.challenge_id, identityToken: 'fixture-identity', authorizationCode: 'fixture-code' };
  identity = { sub: 'fixture-owner', nonce: 'incorrect' };
  await assert.rejects(service.login(args), { code: 'AUTH_CHALLENGE_INVALID' });
  identity.nonce = challenge.nonce;
  await service.login(args);
  await assert.rejects(service.login(args), { code: 'AUTH_CHALLENGE_INVALID' });
});

test('expired challenges and mismatched exchange identities are rejected', async () => {
  const challenge = await service.challenge();
  identity = { sub: 'fixture-owner', nonce: challenge.nonce };
  await pool.query("UPDATE nomadfi.auth_challenges SET expires_at = now() - interval '1 second'");
  await assert.rejects(service.login({ challengeID: challenge.challenge_id, identityToken: 'fixture', authorizationCode: 'fixture' }),
    { code: 'AUTH_CHALLENGE_INVALID' });
  redeemed = { sub: 'other', nonce: challenge.nonce };
  await assert.rejects(login(), { code: 'APPLE_IDENTITY_INVALID' });
});

test('pilot sign-in requires an allowed verified Apple subject', async () => {
  const challenge = await service.challenge();
  identity = { sub: 'other', nonce: challenge.nonce };
  await assert.rejects(service.login({ challengeID: challenge.challenge_id, identityToken: 'fixture', authorizationCode: 'fixture' }),
    { code: 'PILOT_ACCESS_REQUIRED' });
});

test('refresh rotates both credentials and replay revokes the session family', async () => {
  const first = await login();
  const second = await service.refresh(first.refresh_token);
  await assert.rejects(service.authenticate(first.access_token), { code: 'SESSION_INVALID' });
  assert.equal((await service.authenticate(second.access_token)).user_id, first.user_id);
  await assert.rejects(service.refresh(first.refresh_token), { code: 'SESSION_INVALID' });
  await assert.rejects(service.authenticate(second.access_token), { code: 'SESSION_INVALID' });
});

test('concurrent refresh replay cannot leave a live session after reuse', async () => {
  const first = await login();
  const results = await Promise.allSettled([service.refresh(first.refresh_token), service.refresh(first.refresh_token)]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const next = results.find(result => result.status === 'fulfilled').value;
  await assert.rejects(service.authenticate(next.access_token), { code: 'SESSION_INVALID' });
});

test('expired sessions and logout cannot be refreshed', async () => {
  const first = await login();
  const session = await service.authenticate(first.access_token);
  await service.logout(session.id, session.user_id);
  await assert.rejects(service.refresh(first.refresh_token), { code: 'SESSION_INVALID' });
  const next = await login();
  await pool.query("UPDATE nomadfi.sessions SET refresh_expires_at = now() - interval '1 second'");
  await assert.rejects(service.refresh(next.refresh_token), { code: 'SESSION_INVALID' });
});

test('daily Apple grant validation stops revoked identities renewing sessions', async () => {
  const first = await login();
  await pool.query("UPDATE nomadfi.apple_grants SET verified_at = now() - interval '2 days'");
  const next = await service.refresh(first.refresh_token);
  assert.equal(validated, 1);
  await pool.query("UPDATE nomadfi.apple_grants SET verified_at = now() - interval '2 days'");
  revokeGrant = true;
  await assert.rejects(service.refresh(next.refresh_token), { code: 'APPLE_GRANT_REVOKED' });
  await assert.rejects(service.authenticate(next.access_token), { code: 'SESSION_INVALID' });
});

test('a deleting account cannot log in or continue its existing session', async () => {
  const first = await login();
  await pool.query("UPDATE nomadfi.users SET state = 'deleting' WHERE id = $1", [first.user_id]);
  await assert.rejects(service.authenticate(first.access_token), { code: 'SESSION_INVALID' });
  await assert.rejects(service.refresh(first.refresh_token), { code: 'SESSION_INVALID' });
  await assert.rejects(login(), { code: 'ACCOUNT_DELETING' });
});
