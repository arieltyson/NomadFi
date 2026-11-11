import { randomUUID } from 'node:crypto';
import { transaction } from './database.js';
import { ServiceError, uuid } from './security.js';

export class DeliveryService {
  constructor(pool) { this.pool = pool; }
  async begin(userID) {
    return transaction(this.pool, async client => {
      const user = (await client.query(`SELECT delivery_revision FROM nomadfi.users
        WHERE id = $1 AND state = 'active' FOR UPDATE`, [userID])).rows[0];
      if (!user) throw new ServiceError('NOT_FOUND', 404);
      // A device only ever needs the newest snapshot, so starting one
      // supersedes the user's earlier ones. Refusing instead locked out a
      // device whose unfinished downloads had used the quota until they expired.
      await client.query('DELETE FROM nomadfi.snapshots WHERE user_id = $1', [userID]);
      const id = randomUUID();
      await client.query('INSERT INTO nomadfi.snapshots (id, user_id, revision) VALUES ($1, $2, $3)', [id, userID, user.delivery_revision]);
      await client.query(`INSERT INTO nomadfi.snapshot_records
        (snapshot_id, ordinal, connection_id, kind, external_id, payload, removed)
        SELECT $1, row_number() OVER (ORDER BY connection_id, kind, external_id),
          connection_id, kind, external_id, payload, removed FROM nomadfi.ledger_records WHERE user_id = $2`, [id, userID]);
      return { snapshot_id: id, revision: user.delivery_revision };
    });
  }
  async page(userID, snapshotID, after = '0', limit = 200) {
    uuid(snapshotID);
    if (!/^(0|[1-9][0-9]{0,17})$/.test(after) || !Number.isSafeInteger(limit) || limit < 1 || limit > 1000) {
      throw new ServiceError('INVALID_PAGE');
    }
    return transaction(this.pool, async client => {
      const snapshot = (await client.query(`SELECT s.revision FROM nomadfi.snapshots s JOIN nomadfi.users u ON u.id = s.user_id
        WHERE s.id = $1 AND s.user_id = $2 AND s.expires_at > clock_timestamp() AND u.state = 'active'
        FOR SHARE OF s`, [snapshotID, userID])).rows[0];
      if (!snapshot) throw new ServiceError('SNAPSHOT_EXPIRED', 410);
      const result = await client.query(`SELECT ordinal, connection_id, kind, external_id, payload, removed
        FROM nomadfi.snapshot_records WHERE snapshot_id = $1 AND ordinal > $2 ORDER BY ordinal LIMIT $3`, [snapshotID, after, limit + 1]);
      const records = result.rows.slice(0, limit), hasMore = result.rows.length > limit;
      return { records, hasMore, after: records.at(-1)?.ordinal ?? after,
        checkpoint: { revision: snapshot.revision, offset: 2147483647 } };
    });
  }
}
