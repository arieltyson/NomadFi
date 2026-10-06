import { randomUUID } from 'node:crypto';
import { transaction } from './database.js';
import { digest, equalDigest, requiredString, secret, ServiceError, uuid } from './security.js';
import { tokenContext } from './token-cipher.js';

const accessSeconds = 900;
const refreshDays = 30;

export class AuthService {
  constructor({ pool, apple, cipher, allowedSubjects, clock = () => new Date() }) {
    this.pool = pool;
    this.apple = apple;
    this.cipher = cipher;
    this.allowedSubjects = new Set(allowedSubjects);
    this.clock = clock;
  }
  async challenge() {
    const id = randomUUID(), nonce = secret();
    await this.pool.query(`INSERT INTO nomadfi.auth_challenges (id, nonce_digest, expires_at)
      VALUES ($1, $2, clock_timestamp() + interval '5 minutes')`, [id, digest(nonce)]);
    return { challenge_id: id, nonce, expires_in: 300 };
  }
  async login({ challengeID, identityToken, authorizationCode }) {
    uuid(challengeID);
    const identity = await this.apple.verify(identityToken, { fresh: true });
    if (!this.allowedSubjects.has(identity.sub)) throw new ServiceError('PILOT_ACCESS_REQUIRED', 403);
    if (typeof identity.nonce !== 'string') throw new ServiceError('AUTH_CHALLENGE_INVALID', 401);
    const result = await this.pool.query(`UPDATE nomadfi.auth_challenges SET consumed_at = clock_timestamp()
      WHERE id = $1 AND nonce_digest = $2 AND consumed_at IS NULL AND expires_at > clock_timestamp()
      RETURNING id`, [challengeID, digest(identity.nonce)]);
    if (!result.rowCount) throw new ServiceError('AUTH_CHALLENGE_INVALID', 401);
    const grant = await this.apple.redeem(requiredString(authorizationCode));
    if (grant.identity.sub !== identity.sub || grant.identity.nonce !== identity.nonce) {
      throw new ServiceError('APPLE_IDENTITY_INVALID', 401);
    }
    const grantID = randomUUID();
    const user = (await this.pool.query(`INSERT INTO nomadfi.users (id, apple_subject) VALUES ($1, $2)
      ON CONFLICT (apple_subject) DO UPDATE SET apple_subject = EXCLUDED.apple_subject RETURNING id, state`,
    [randomUUID(), identity.sub])).rows[0];
    if (user.state !== 'active') throw new ServiceError('ACCOUNT_DELETING', 403);
    const encrypted = await this.cipher.encrypt(grant.refreshToken, tokenContext('apple', user.id, grantID, 'identity'));
    return transaction(this.pool, async client => {
      const current = (await client.query('SELECT state FROM nomadfi.users WHERE id = $1 FOR UPDATE', [user.id])).rows[0];
      if (current?.state !== 'active') throw new ServiceError('ACCOUNT_DELETING', 403);
      await client.query(`INSERT INTO nomadfi.apple_grants (id, user_id, key_id, encrypted_token)
        VALUES ($1, $2, $3, $4)`, [grantID, user.id, encrypted.keyID, encrypted.encryptedToken]);
      const tokens = { access_token: secret(), refresh_token: secret(), expires_in: accessSeconds };
      await client.query(`INSERT INTO nomadfi.sessions
        (id, user_id, apple_grant_id, access_digest, refresh_digest, access_expires_at, refresh_expires_at, absolute_expires_at)
        VALUES ($1, $2, $3, $4, $5, clock_timestamp() + make_interval(secs => $6),
          clock_timestamp() + make_interval(days => $7), clock_timestamp() + interval '90 days')`,
      [randomUUID(), user.id, grantID, digest(tokens.access_token), digest(tokens.refresh_token), accessSeconds, refreshDays]);
      return { ...tokens, user_id: user.id };
    });
  }
  async authenticate(accessToken) {
    const result = await this.pool.query(`SELECT s.id, s.user_id FROM nomadfi.sessions s
      JOIN nomadfi.users u ON u.id = s.user_id JOIN nomadfi.apple_grants g ON g.id = s.apple_grant_id
      WHERE s.access_digest = $1 AND s.revoked_at IS NULL AND s.access_expires_at > clock_timestamp()
        AND u.state = 'active' AND g.revoked_at IS NULL`, [digest(requiredString(accessToken, 256))]);
    if (!result.rowCount) throw new ServiceError('SESSION_INVALID', 401);
    return result.rows[0];
  }
  async refresh(refreshToken) {
    const tokenDigest = digest(requiredString(refreshToken, 256));
    const lookup = await this.pool.query(`SELECT s.*, u.apple_subject, g.key_id, g.encrypted_token, g.verified_at,
        g.revoked_at AS grant_revoked_at
      FROM nomadfi.sessions s JOIN nomadfi.users u ON u.id = s.user_id
      JOIN nomadfi.apple_grants g ON g.id = s.apple_grant_id
      WHERE s.refresh_digest = $1 OR s.id IN
        (SELECT session_id FROM nomadfi.spent_refresh_tokens WHERE digest = $1)`, [tokenDigest]);
    if (!lookup.rowCount) throw new ServiceError('SESSION_INVALID', 401);
    const session = lookup.rows[0];
    if (session.revoked_at || session.grant_revoked_at || session.refresh_expires_at <= this.clock()) {
      throw new ServiceError('SESSION_INVALID', 401);
    }
    if (equalDigest(tokenDigest, session.refresh_digest)
        && this.clock().getTime() - session.verified_at.getTime() >= 86400000) {
      try {
        const appleToken = await this.cipher.decrypt({ keyID: session.key_id, encryptedToken: session.encrypted_token },
          tokenContext('apple', session.user_id, session.apple_grant_id, 'identity'));
        await this.apple.validateGrant(appleToken, session.apple_subject);
        await this.pool.query('UPDATE nomadfi.apple_grants SET verified_at = clock_timestamp() WHERE id = $1', [session.apple_grant_id]);
      } catch (error) {
        if (error.status === 401) await this.pool.query(`UPDATE nomadfi.sessions SET revoked_at = clock_timestamp()
          WHERE user_id = $1`, [session.user_id]);
        throw error;
      }
    }
    const outcome = await transaction(this.pool, async client => {
      const user = (await client.query(`SELECT state FROM nomadfi.users WHERE id = $1 FOR UPDATE`, [session.user_id])).rows[0];
      const current = (await client.query(`SELECT s.*, s.refresh_expires_at > clock_timestamp() AS valid,
        s.absolute_expires_at > clock_timestamp() AS within_lifetime, g.revoked_at AS grant_revoked_at
        FROM nomadfi.sessions s JOIN nomadfi.apple_grants g ON g.id = s.apple_grant_id
        WHERE s.id = $1 FOR UPDATE OF s, g`, [session.id])).rows[0];
      if (!current || user?.state !== 'active' || current.revoked_at || current.grant_revoked_at
          || !current.valid || !current.within_lifetime) return null;
      if (!equalDigest(current.refresh_digest, tokenDigest)) {
        await client.query('UPDATE nomadfi.sessions SET revoked_at = clock_timestamp() WHERE id = $1', [current.id]);
        return null;
      }
      await client.query('INSERT INTO nomadfi.spent_refresh_tokens (digest, session_id) VALUES ($1, $2)', [tokenDigest, current.id]);
      const tokens = { access_token: secret(), refresh_token: secret(), expires_in: accessSeconds };
      await client.query(`UPDATE nomadfi.sessions SET access_digest = $2, refresh_digest = $3,
        access_expires_at = clock_timestamp() + make_interval(secs => $4),
        refresh_expires_at = LEAST(absolute_expires_at, clock_timestamp() + make_interval(days => $5)) WHERE id = $1`,
      [current.id, digest(tokens.access_token), digest(tokens.refresh_token), accessSeconds, refreshDays]);
      return { ...tokens, user_id: current.user_id };
    });
    if (!outcome) throw new ServiceError('SESSION_INVALID', 401);
    return outcome;
  }
  async logout(sessionID, userID) {
    await this.pool.query('UPDATE nomadfi.sessions SET revoked_at = clock_timestamp() WHERE id = $1 AND user_id = $2', [sessionID, userID]);
  }
}
