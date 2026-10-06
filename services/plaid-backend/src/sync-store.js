import { randomUUID } from 'node:crypto';
import { transaction } from './database.js';

export class StoreError extends Error {
  constructor(code) { super(code); this.code = code; }
}

function requireRow(result, code = 'NOT_FOUND') {
  if (!result.rowCount) throw new StoreError(code);
  return result.rows[0];
}

function validatePage(page) {
  if (!Number.isSafeInteger(page.index) || page.index < 0
      || typeof page.nextCursor !== 'string' || page.nextCursor.length > 8192
      || typeof page.hasMore !== 'boolean' || !Array.isArray(page.events)
      || page.events.length > 1000) throw new StoreError('INVALID_PAGE');
  for (const event of page.events) {
    if (!['account', 'removed_account', 'transaction', 'removed_transaction'].includes(event.kind)
        || typeof event.externalID !== 'string' || !event.externalID.length || event.externalID.length > 512
        || !event.payload || Array.isArray(event.payload) || typeof event.payload !== 'object'
        || Buffer.byteLength(JSON.stringify(event.payload)) > 65536) throw new StoreError('INVALID_EVENT');
  }
  if (Buffer.byteLength(JSON.stringify(page)) > 2 * 1024 * 1024) throw new StoreError('PAGE_TOO_LARGE');
}

export class SyncStore {
  constructor(pool) { this.pool = pool; }

  async createUser(appleSubject) {
    const result = await this.pool.query(`INSERT INTO nomadfi.users (id, apple_subject)
      VALUES ($1, $2) ON CONFLICT (apple_subject) DO UPDATE SET apple_subject = EXCLUDED.apple_subject
      RETURNING id`, [randomUUID(), appleSubject]);
    return result.rows[0].id;
  }

  async addConnection({ id = randomUUID(), userID, environment, providerItemID, institutionName = null, keyID, encryptedToken }) {
    if (!Buffer.isBuffer(encryptedToken) || encryptedToken.length < 32) throw new StoreError('ENCRYPTION_REQUIRED');
    return transaction(this.pool, async client => {
      requireRow(await client.query(`SELECT id FROM nomadfi.users WHERE id = $1 AND state = 'active'
        FOR UPDATE`, [userID]));
      await client.query(`INSERT INTO nomadfi.connections (id, user_id, environment, provider_item_id, institution_name)
        VALUES ($1, $2, $3, $4, $5)`, [id, userID, environment, providerItemID, institutionName]);
      await client.query(`INSERT INTO nomadfi.credentials (connection_id, user_id, key_id, encrypted_token)
        VALUES ($1, $2, $3, $4)`, [id, userID, keyID, encryptedToken]);
      await client.query(`INSERT INTO nomadfi.sync_jobs (connection_id, user_id) VALUES ($1, $2)`, [id, userID]);
      return id;
    });
  }

  async connections(userID) {
    const result = await this.pool.query(`SELECT c.id, c.environment, c.institution_name, c.state, c.last_synced_at
      FROM nomadfi.connections c JOIN nomadfi.users u ON u.id = c.user_id
      WHERE c.user_id = $1 AND u.state = 'active' ORDER BY c.created_at, c.id`, [userID]);
    return result.rows;
  }

  async requestSync(userID, connectionID) {
    const result = await this.pool.query(`UPDATE nomadfi.sync_jobs j
      SET requested_revision = requested_revision + 1
      FROM nomadfi.connections c, nomadfi.users u
      WHERE j.connection_id = $1 AND j.user_id = $2 AND c.id = j.connection_id
        AND u.id = j.user_id AND u.state = 'active' AND c.state = 'connected'
      RETURNING j.connection_id`, [connectionID, userID]);
    requireRow(result);
  }

  async claim(leaseSeconds = 60) {
    if (!Number.isSafeInteger(leaseSeconds) || leaseSeconds < 1 || leaseSeconds > 300) throw new StoreError('INVALID_LEASE');
    return transaction(this.pool, async client => {
      await client.query(`UPDATE nomadfi.sync_jobs SET dead_letter = true, failure_code = 'worker_failed'
        WHERE attempts >= 8 AND NOT dead_letter AND requested_revision > completed_revision
          AND lease_expires_at <= clock_timestamp()`);
      const selected = await client.query(`SELECT j.connection_id FROM nomadfi.sync_jobs j
        JOIN nomadfi.connections c ON c.id = j.connection_id JOIN nomadfi.users u ON u.id = j.user_id
        WHERE j.requested_revision > j.completed_revision AND NOT j.dead_letter
          AND j.available_at <= clock_timestamp()
          AND (j.lease_expires_at IS NULL OR j.lease_expires_at <= clock_timestamp())
          AND c.state = 'connected' AND u.state = 'active'
        ORDER BY j.available_at, j.connection_id LIMIT 1 FOR UPDATE OF j SKIP LOCKED`);
      if (!selected.rowCount) return null;
      return requireRow(await client.query(`UPDATE nomadfi.sync_jobs SET
        lease_epoch = lease_epoch + 1, leased_request_revision = requested_revision,
        lease_expires_at = clock_timestamp() + make_interval(secs => $2), attempts = attempts + 1
        WHERE connection_id = $1 RETURNING *`, [selected.rows[0].connection_id, leaseSeconds]));
    });
  }

  async assertLease(client, claim) {
    return requireRow(await client.query(`SELECT j.* FROM nomadfi.sync_jobs j
      JOIN nomadfi.connections c ON c.id = j.connection_id JOIN nomadfi.users u ON u.id = j.user_id
      WHERE j.connection_id = $1 AND j.user_id = $2 AND j.lease_epoch = $3
        AND j.lease_expires_at > clock_timestamp() AND c.state = 'connected' AND u.state = 'active'
      FOR UPDATE OF j`, [claim.connection_id, claim.user_id, claim.lease_epoch]), 'LEASE_LOST');
  }

  async renew(claim, leaseSeconds = 60) {
    if (!Number.isSafeInteger(leaseSeconds) || leaseSeconds < 1 || leaseSeconds > 300) throw new StoreError('INVALID_LEASE');
    return transaction(this.pool, async client => {
      await this.assertLease(client, claim);
      await client.query(`UPDATE nomadfi.sync_jobs
        SET lease_expires_at = clock_timestamp() + make_interval(secs => $2) WHERE connection_id = $1`,
      [claim.connection_id, leaseSeconds]);
    });
  }

  async beginGeneration(claim) {
    return transaction(this.pool, async client => {
      await this.assertLease(client, claim);
      const connection = requireRow(await client.query(`SELECT upstream_cursor FROM nomadfi.connections
        WHERE id = $1 AND user_id = $2`, [claim.connection_id, claim.user_id]));
      const id = randomUUID();
      await client.query(`INSERT INTO nomadfi.sync_generations
        (id, connection_id, user_id, lease_epoch, base_cursor, next_cursor)
        VALUES ($1, $2, $3, $4, $5, $5)`, [id, claim.connection_id, claim.user_id, claim.lease_epoch, connection.upstream_cursor]);
      return { id, cursor: connection.upstream_cursor };
    });
  }

  async stagePage(claim, generationID, page) {
    validatePage(page);
    return transaction(this.pool, async client => {
      await this.assertLease(client, claim);
      const generation = requireRow(await client.query(`SELECT * FROM nomadfi.sync_generations
        WHERE id = $1 AND connection_id = $2 AND user_id = $3 AND lease_epoch = $4
        FOR UPDATE`, [generationID, claim.connection_id, claim.user_id, claim.lease_epoch]));
      if (generation.complete || generation.published_at || generation.page_count !== page.index
          || generation.next_cursor !== page.cursor) throw new StoreError('PAGE_ORDER');
      if (page.hasMore && page.nextCursor === page.cursor) throw new StoreError('CURSOR_NOT_ADVANCING');
      const data = page.events.map((event, offset) => ({
        ordinal: generation.event_count + offset, kind: event.kind, external_id: event.externalID, payload: event.payload,
      }));
      await client.query(`INSERT INTO nomadfi.sync_events
        (generation_id, connection_id, user_id, ordinal, kind, external_id, payload)
        SELECT $1, $2, $3, e.ordinal, e.kind, e.external_id, e.payload
        FROM jsonb_to_recordset($4::jsonb) AS e(ordinal integer, kind text, external_id text, payload jsonb)`,
      [generationID, claim.connection_id, claim.user_id, JSON.stringify(data)]);
      await client.query(`UPDATE nomadfi.sync_generations SET page_count = page_count + 1,
        event_count = event_count + $2, next_cursor = $3, complete = $4 WHERE id = $1`,
      [generationID, data.length, page.nextCursor, !page.hasMore]);
    });
  }

  async publish(claim, generationID) {
    return transaction(this.pool, async client => {
      requireRow(await client.query(`SELECT id FROM nomadfi.users WHERE id = $1 AND state = 'active'
        FOR UPDATE`, [claim.user_id]));
      const lease = await this.assertLease(client, claim);
      const generation = requireRow(await client.query(`SELECT * FROM nomadfi.sync_generations
        WHERE id = $1 AND user_id = $2 AND connection_id = $3 AND lease_epoch = $4
        FOR UPDATE`, [generationID, claim.user_id, claim.connection_id, claim.lease_epoch]));
      if (!generation.complete || generation.published_at) throw new StoreError('INCOMPLETE_OR_PUBLISHED');
      const connection = requireRow(await client.query(`SELECT upstream_cursor FROM nomadfi.connections
        WHERE id = $1 AND user_id = $2 FOR UPDATE`, [claim.connection_id, claim.user_id]));
      if (connection.upstream_cursor !== generation.base_cursor) throw new StoreError('CURSOR_CONFLICT');
      const revision = requireRow(await client.query(`UPDATE nomadfi.users SET delivery_revision = delivery_revision + 1
        WHERE id = $1 RETURNING delivery_revision`, [claim.user_id])).delivery_revision;
      await client.query(`INSERT INTO nomadfi.ledger_records
        (connection_id, user_id, kind, external_id, payload, removed, revision)
        SELECT DISTINCT ON (replace(kind, 'removed_', ''), external_id)
          connection_id, user_id, replace(kind, 'removed_', ''), external_id, payload,
          kind LIKE 'removed_%', $2 FROM nomadfi.sync_events WHERE generation_id = $1
        ORDER BY replace(kind, 'removed_', ''), external_id, ordinal DESC
        ON CONFLICT (connection_id, kind, external_id) DO UPDATE SET
          payload = EXCLUDED.payload, removed = EXCLUDED.removed, revision = EXCLUDED.revision`,
      [generationID, revision]);
      await client.query(`UPDATE nomadfi.sync_generations SET delivery_revision = $2,
        published_at = clock_timestamp() WHERE id = $1`, [generationID, revision]);
      await client.query(`UPDATE nomadfi.connections SET upstream_cursor = $2,
        last_synced_at = clock_timestamp() WHERE id = $1`, [claim.connection_id, generation.next_cursor]);
      await client.query(`UPDATE nomadfi.sync_jobs SET completed_revision = $2, lease_expires_at = NULL,
        attempts = 0, failure_code = NULL, available_at = clock_timestamp() WHERE connection_id = $1`,
      [claim.connection_id, lease.leased_request_revision]);
      return revision;
    });
  }

  async fail(claim, code, retrySeconds = 60) {
    if (!['upstream_unavailable', 'invalid_data', 'worker_failed'].includes(code)
        || !Number.isSafeInteger(retrySeconds) || retrySeconds < 1 || retrySeconds > 86400) throw new StoreError('INVALID_FAILURE');
    return transaction(this.pool, async client => {
      await this.assertLease(client, claim);
      await client.query(`UPDATE nomadfi.sync_jobs SET lease_expires_at = NULL, failure_code = $2,
        available_at = clock_timestamp() + make_interval(secs => $3), dead_letter = attempts >= 8
        WHERE connection_id = $1`, [claim.connection_id, code, retrySeconds]);
    });
  }

  async discard(claim, generationID) {
    return transaction(this.pool, async client => {
      await this.assertLease(client, claim);
      await client.query(`DELETE FROM nomadfi.sync_generations WHERE id = $1 AND connection_id = $2
        AND user_id = $3 AND lease_epoch = $4 AND published_at IS NULL`,
      [generationID, claim.connection_id, claim.user_id, claim.lease_epoch]);
    });
  }

  async changes(userID, { revision = '0', offset = -1, through = null, limit = 200 } = {}) {
    if (!/^(0|[1-9][0-9]{0,17})$/.test(revision) || (through !== null && !/^(0|[1-9][0-9]{0,17})$/.test(through))
        || !Number.isSafeInteger(offset) || offset < -1 || offset > 2147483647
        || !Number.isSafeInteger(limit) || limit < 1 || limit > 1000) {
      throw new StoreError('INVALID_CHECKPOINT');
    }
    const current = requireRow(await this.pool.query(`SELECT delivery_revision FROM nomadfi.users
      WHERE id = $1 AND state = 'active'`, [userID])).delivery_revision;
    const ceiling = through ?? current;
    if (BigInt(ceiling) > BigInt(current) || BigInt(revision) > BigInt(ceiling)) throw new StoreError('INVALID_CHECKPOINT');
    const result = await this.pool.query(`SELECT g.delivery_revision, e.ordinal, e.connection_id,
        e.kind, e.external_id, e.payload
      FROM nomadfi.sync_generations g JOIN nomadfi.sync_events e ON e.generation_id = g.id
      WHERE g.user_id = $1 AND g.delivery_revision <= $4 AND g.published_at IS NOT NULL
        AND (g.delivery_revision > $2 OR (g.delivery_revision = $2 AND e.ordinal > $3))
      ORDER BY g.delivery_revision, e.ordinal LIMIT $5`, [userID, revision, offset, ceiling, limit + 1]);
    const hasMore = result.rows.length > limit;
    const events = result.rows.slice(0, limit);
    const last = events.at(-1);
    return {
      events, through: ceiling, hasMore,
      checkpoint: hasMore ? { revision: last.delivery_revision, offset: last.ordinal }
        : { revision: ceiling, offset: 2147483647 },
    };
  }

  async acknowledge(userID, deviceID, { revision, offset }) {
    if (!/^(0|[1-9][0-9]{0,17})$/.test(revision) || !Number.isSafeInteger(offset)
        || offset < -1 || offset > 2147483647) throw new StoreError('INVALID_CHECKPOINT');
    return transaction(this.pool, async client => {
      const user = requireRow(await client.query(`SELECT delivery_revision FROM nomadfi.users
        WHERE id = $1 AND state = 'active' FOR UPDATE`, [userID]));
      if (BigInt(revision) > BigInt(user.delivery_revision)) throw new StoreError('INVALID_CHECKPOINT');
      if (offset !== -1 && offset !== 2147483647) {
        requireRow(await client.query(`SELECT e.ordinal FROM nomadfi.sync_events e
          JOIN nomadfi.sync_generations g ON g.id = e.generation_id
          WHERE g.user_id = $1 AND g.delivery_revision = $2 AND e.ordinal = $3`,
        [userID, revision, offset]), 'INVALID_CHECKPOINT');
      }
      await client.query(`INSERT INTO nomadfi.device_checkpoints (user_id, device_id, revision, event_offset)
        VALUES ($1, $2, $3, $4) ON CONFLICT (user_id, device_id) DO UPDATE
        SET revision = EXCLUDED.revision, event_offset = EXCLUDED.event_offset, updated_at = clock_timestamp()
        WHERE (nomadfi.device_checkpoints.revision, nomadfi.device_checkpoints.event_offset)
          < (EXCLUDED.revision, EXCLUDED.event_offset)`, [userID, deviceID, revision, offset]);
    });
  }
}
