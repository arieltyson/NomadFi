import { decodeProtectedHeader, importJWK, jwtVerify } from 'jose';
import { digest, equalDigest, requiredString, ServiceError } from './security.js';
import { transaction } from './database.js';

export class WebhookService {
  constructor({ pool, plaid, clock = () => new Date() }) {
    this.pool = pool; this.plaid = plaid; this.clock = clock; this.keys = new Map();
  }
  async verify(rawBody, verification) {
    try {
      if (!Buffer.isBuffer(rawBody) || rawBody.length > 262144) throw new Error();
      requiredString(verification, 8192);
      const header = decodeProtectedHeader(verification);
      if (header.alg !== 'ES256' || typeof header.kid !== 'string' || !/^[\w-]{1,128}$/.test(header.kid)) throw new Error();
      let cached = this.keys.get(header.kid);
      if (!cached || cached.expires <= this.clock().getTime()) {
        const { key } = await this.plaid.request('/webhook_verification_key/get', { key_id: header.kid });
        if (!key || key.kid !== header.kid || key.alg !== 'ES256' || key.kty !== 'EC'
            || key.crv !== 'P-256' || key.expired_at != null) throw new Error();
        cached = { key: await importJWK(key, 'ES256'), expires: this.clock().getTime() + 60000 };
        if (this.keys.size >= 16) this.keys.delete(this.keys.keys().next().value);
        this.keys.set(header.kid, cached);
      }
      const { payload } = await jwtVerify(verification, cached.key, {
        algorithms: ['ES256'], requiredClaims: ['iat', 'request_body_sha256'],
        maxTokenAge: '5m', clockTolerance: 5, currentDate: this.clock(),
      });
      if (typeof payload.request_body_sha256 !== 'string' || !/^[a-f0-9]{64}$/i.test(payload.request_body_sha256)
          || !equalDigest(digest(rawBody), Buffer.from(payload.request_body_sha256, 'hex'))) throw new Error();
      return JSON.parse(rawBody.toString('utf8'));
    } catch (error) {
      if (error.code === 'PLAID_UNAVAILABLE') throw error;
      throw new ServiceError('WEBHOOK_INVALID', 401);
    }
  }
  async receive(rawBody, verification) {
    const event = await this.verify(rawBody, verification);
    if (event.environment !== this.plaid.environment) throw new ServiceError('WEBHOOK_INVALID', 401);
    return transaction(this.pool, async client => {
      const receipt = await client.query(`INSERT INTO nomadfi.webhook_receipts (digest) VALUES ($1)
        ON CONFLICT DO NOTHING RETURNING digest`, [digest(verification)]);
      if (!receipt.rowCount) return { accepted: true };
      const connection = (await client.query(`SELECT c.id, c.user_id FROM nomadfi.connections c
        JOIN nomadfi.users u ON u.id = c.user_id WHERE c.provider_item_id = $1
          AND c.environment = $2 AND c.state = 'connected' AND u.state = 'active'`,
      [typeof event.item_id === 'string' ? event.item_id : '', this.plaid.environment])).rows[0];
      if (!connection) return { accepted: true };
      if (event.webhook_type === 'TRANSACTIONS' && event.webhook_code === 'SYNC_UPDATES_AVAILABLE') {
        await client.query(`UPDATE nomadfi.sync_jobs SET requested_revision = requested_revision + 1
          WHERE connection_id = $1`, [connection.id]);
        return { accepted: true, queued: true };
      } else if (event.webhook_type === 'ITEM' && (event.webhook_code === 'USER_PERMISSION_REVOKED'
          || (event.webhook_code === 'ERROR' && event.error?.error_code === 'ITEM_LOGIN_REQUIRED'))) {
        await client.query("UPDATE nomadfi.connections SET state = 'reconnect_required' WHERE id = $1", [connection.id]);
      }
      return { accepted: true };
    });
  }
}

export async function enqueueStaleConnections(pool, hours = 12) {
  if (!Number.isInteger(hours) || hours < 6 || hours > 168) throw new ServiceError('INVALID_SWEEP_INTERVAL');
  const result = await pool.query(`UPDATE nomadfi.sync_jobs j SET requested_revision = requested_revision + 1
    FROM nomadfi.connections c, nomadfi.users u WHERE c.id = j.connection_id AND u.id = c.user_id
      AND c.state = 'connected' AND u.state = 'active' AND NOT j.dead_letter
      AND j.requested_revision = j.completed_revision
      AND (c.last_synced_at IS NULL OR c.last_synced_at < clock_timestamp() - make_interval(hours => $1))
    RETURNING j.connection_id`, [hours]);
  return result.rowCount;
}
