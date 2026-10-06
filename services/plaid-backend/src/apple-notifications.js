import { transaction } from './database.js';
import { digest } from './security.js';

export class AppleNotifications {
  constructor({ pool, apple, revocation }) { this.pool = pool; this.apple = apple; this.revocation = revocation; }
  async receive(token) {
    const event = await this.apple.verifyNotification(token);
    await transaction(this.pool, async client => {
      const receipt = await client.query(`INSERT INTO nomadfi.apple_events (id_digest) VALUES ($1)
        ON CONFLICT DO NOTHING RETURNING id_digest`, [digest(event.id)]);
      if (!receipt.rowCount) return;
      const user = (await client.query('SELECT id, created_at FROM nomadfi.users WHERE apple_subject = $1 FOR UPDATE', [event.subject])).rows[0];
      if (!user || Math.floor(user.created_at.getTime() / 1000) > event.time.getTime() / 1000) return;
      if (event.type === 'account-deleted') { await this.revocation.deleteAccount(user.id, client); return; }
      if (event.type !== 'consent-revoked') return;
      await client.query(`UPDATE nomadfi.sessions SET revoked_at = clock_timestamp()
        WHERE user_id = $1 AND date_trunc('second', created_at) <= $2`, [user.id, event.time]);
      const reauthorized = await client.query(`SELECT id FROM nomadfi.sessions WHERE user_id = $1 AND revoked_at IS NULL
        AND date_trunc('second', created_at) > $2 LIMIT 1`, [user.id, event.time]);
      if (!reauthorized.rowCount) {
        await client.query('UPDATE nomadfi.apple_grants SET revoked_at = clock_timestamp() WHERE user_id = $1', [user.id]);
        await client.query(`UPDATE nomadfi.connections SET state = 'reconnect_required'
          WHERE user_id = $1 AND state = 'connected'`, [user.id]);
      }
    });
    return { accepted: true };
  }
}
