import { randomUUID } from 'node:crypto';
import { transaction } from './database.js';
import { ServiceError, uuid } from './security.js';
import { tokenContext } from './token-cipher.js';

export class RevocationService {
  constructor({ pool, cipher, plaid, apple }) { this.pool = pool; this.cipher = cipher; this.plaid = plaid; this.apple = apple; }
  async disconnect(userID, connectionID) {
    uuid(connectionID);
    await transaction(this.pool, async client => {
      const user = (await client.query('SELECT state FROM nomadfi.users WHERE id = $1 FOR UPDATE', [userID])).rows[0];
      if (user?.state !== 'active') throw new ServiceError('NOT_FOUND', 404);
      const row = (await client.query(`UPDATE nomadfi.connections SET state = CASE WHEN state = 'disconnected'
        THEN state ELSE 'revoking' END WHERE id = $1 AND user_id = $2 RETURNING state`, [connectionID, userID])).rows[0];
      if (!row) throw new ServiceError('NOT_FOUND', 404);
      if (row.state === 'disconnected') return;
      await client.query(`INSERT INTO nomadfi.revocation_jobs (id, user_id, purpose, resource_id)
        VALUES ($1, $2, 'plaid', $3) ON CONFLICT (purpose, resource_id) DO NOTHING`, [randomUUID(), userID, connectionID]);
    });
    return { status: 'revoking' };
  }
  async deleteAccount(userID) {
    await transaction(this.pool, async client => {
      const user = await client.query("UPDATE nomadfi.users SET state = 'deleting' WHERE id = $1 RETURNING id", [userID]);
      if (!user.rowCount) throw new ServiceError('NOT_FOUND', 404);
      await client.query('UPDATE nomadfi.sessions SET revoked_at = clock_timestamp() WHERE user_id = $1', [userID]);
      await client.query("UPDATE nomadfi.connections SET state = 'revoking' WHERE user_id = $1 AND state <> 'disconnected'", [userID]);
      const resources = await client.query(`SELECT 'plaid' AS purpose, id FROM nomadfi.connections
        WHERE user_id = $1 AND state = 'revoking' UNION ALL
        SELECT 'apple', id FROM nomadfi.apple_grants WHERE user_id = $1 AND revoked_at IS NULL`, [userID]);
      for (const row of resources.rows) await client.query(`INSERT INTO nomadfi.revocation_jobs (id, user_id, purpose, resource_id)
        VALUES ($1, $2, $3, $4) ON CONFLICT (purpose, resource_id) DO NOTHING`, [randomUUID(), userID, row.purpose, row.id]);
    });
    return { status: 'deleting' };
  }
  async runOne() {
    const job = await transaction(this.pool, async client => {
      await client.query(`UPDATE nomadfi.revocation_jobs SET dead_letter = true WHERE attempts >= 8
        AND completed_at IS NULL AND lease_expires_at <= clock_timestamp()`);
      const row = (await client.query(`SELECT id FROM nomadfi.revocation_jobs WHERE completed_at IS NULL
        AND NOT dead_letter AND available_at <= clock_timestamp()
        AND (lease_expires_at IS NULL OR lease_expires_at <= clock_timestamp())
        ORDER BY available_at, id LIMIT 1 FOR UPDATE SKIP LOCKED`)).rows[0];
      if (!row) return null;
      return (await client.query(`UPDATE nomadfi.revocation_jobs SET attempts = attempts + 1, lease_epoch = lease_epoch + 1,
        lease_expires_at = clock_timestamp() + interval '2 minutes' WHERE id = $1 RETURNING *`, [row.id])).rows[0];
    });
    if (!job) { await this.purgeCompletedDeletions(); return { status: 'idle' }; }
    try {
      if (job.purpose === 'plaid') {
        const row = (await this.pool.query(`SELECT k.key_id, k.encrypted_token, c.environment FROM nomadfi.credentials k
          JOIN nomadfi.connections c ON c.id = k.connection_id WHERE k.connection_id = $1 AND k.user_id = $2`, [job.resource_id, job.user_id])).rows[0];
        if (row) {
          if (row.environment !== this.plaid.environment) throw new ServiceError('INVALID_ENVIRONMENT');
          const token = await this.cipher.decrypt({ keyID: row.key_id, encryptedToken: row.encrypted_token },
            tokenContext('plaid', job.user_id, job.resource_id, row.environment));
          try { await this.plaid.request('/item/remove', { access_token: token }); }
          catch (error) { if (!['ITEM_NOT_FOUND', 'INVALID_ACCESS_TOKEN'].includes(error.code)) throw error; }
        }
      } else {
        const row = (await this.pool.query('SELECT key_id, encrypted_token FROM nomadfi.apple_grants WHERE id = $1 AND user_id = $2',
          [job.resource_id, job.user_id])).rows[0];
        if (row) {
          const token = await this.cipher.decrypt({ keyID: row.key_id, encryptedToken: row.encrypted_token },
            tokenContext('apple', job.user_id, job.resource_id, 'identity'));
          try { await this.apple.revoke(token); }
          catch (error) { if (error.code !== 'APPLE_GRANT_REVOKED') throw error; }
        }
      }
      await transaction(this.pool, async client => {
        await client.query('SELECT id FROM nomadfi.users WHERE id = $1 FOR UPDATE', [job.user_id]);
        const marked = await client.query(`UPDATE nomadfi.revocation_jobs SET completed_at = clock_timestamp(), lease_expires_at = NULL
          WHERE id = $1 AND lease_epoch = $2 AND lease_expires_at > clock_timestamp() RETURNING id`, [job.id, job.lease_epoch]);
        if (!marked.rowCount) throw new ServiceError('LEASE_LOST', 409);
        if (job.purpose === 'plaid') {
          await client.query("UPDATE nomadfi.connections SET state = 'disconnected' WHERE id = $1 AND user_id = $2", [job.resource_id, job.user_id]);
          await client.query('DELETE FROM nomadfi.credentials WHERE connection_id = $1 AND user_id = $2', [job.resource_id, job.user_id]);
        } else {
          await client.query('UPDATE nomadfi.apple_grants SET revoked_at = clock_timestamp() WHERE id = $1 AND user_id = $2', [job.resource_id, job.user_id]);
          await client.query('DELETE FROM nomadfi.sessions WHERE apple_grant_id = $1 AND user_id = $2', [job.resource_id, job.user_id]);
          await client.query('DELETE FROM nomadfi.apple_grants WHERE id = $1 AND user_id = $2', [job.resource_id, job.user_id]);
        }
      });
      await this.purgeCompletedDeletions();
      return { status: 'revoked' };
    } catch (error) {
      if (error.code === 'LEASE_LOST') return { status: 'lease_lost' };
      await this.pool.query(`UPDATE nomadfi.revocation_jobs SET lease_expires_at = NULL,
        available_at = clock_timestamp() + make_interval(secs => $3), dead_letter = attempts >= 8
        WHERE id = $1 AND lease_epoch = $2`, [job.id, job.lease_epoch, Math.min(3600, 30 * 2 ** Math.min(job.attempts, 7))]);
      return { status: 'retry' };
    }
  }
  async purgeCompletedDeletions() {
    await this.pool.query(`DELETE FROM nomadfi.users u WHERE state = 'deleting'
      AND NOT EXISTS (SELECT 1 FROM nomadfi.revocation_jobs j WHERE j.user_id = u.id AND j.completed_at IS NULL)
      AND NOT EXISTS (SELECT 1 FROM nomadfi.link_attempts l WHERE l.user_id = u.id
        AND l.state NOT IN ('created', 'complete'))`);
  }
}
