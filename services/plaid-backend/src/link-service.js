import { randomUUID } from 'node:crypto';
import { transaction } from './database.js';
import { digest, equalDigest, requiredString, ServiceError, uuid } from './security.js';
import { tokenContext } from './token-cipher.js';

export class LinkService {
  constructor({ pool, plaid, cipher, redirectURI, webhookURL }) {
    for (const value of [redirectURI, webhookURL]) {
      const url = new URL(value);
      if (url.protocol !== 'https:' || url.username || url.password || url.hash) throw new ServiceError('HTTPS_REQUIRED');
    }
    this.pool = pool; this.plaid = plaid; this.cipher = cipher;
    this.redirectURI = redirectURI; this.webhookURL = webhookURL;
  }
  context(purpose, row) { return tokenContext(purpose, row.user_id, row.id, row.environment); }
  async credential(userID, connectionID) {
    uuid(connectionID);
    const row = (await this.pool.query(`SELECT c.*, k.key_id, k.encrypted_token FROM nomadfi.connections c
      JOIN nomadfi.credentials k ON k.connection_id = c.id JOIN nomadfi.users u ON u.id = c.user_id
      WHERE c.id = $1 AND c.user_id = $2 AND u.state = 'active'
        AND c.state IN ('connected', 'reconnect_required')`, [connectionID, userID])).rows[0];
    if (!row || row.environment !== this.plaid.environment) throw new ServiceError('NOT_FOUND', 404);
    return this.cipher.decrypt({ keyID: row.key_id, encryptedToken: row.encrypted_token }, this.context('plaid', row));
  }
  async begin(userID, connectionID = null) {
    const user = await this.pool.query("SELECT id FROM nomadfi.users WHERE id = $1 AND state = 'active'", [userID]);
    if (!user.rowCount) throw new ServiceError('NOT_FOUND', 404);
    const fields = { user: { client_user_id: userID }, client_name: 'NomadFi', country_codes: ['CA', 'US'],
      language: 'en', redirect_uri: this.redirectURI, webhook: this.webhookURL };
    if (connectionID) {
      fields.access_token = await this.credential(userID, connectionID);
      fields.update = { account_selection_enabled: true };
    } else {
      fields.products = ['transactions']; fields.transactions = { days_requested: 365 };
    }
    const result = await this.plaid.request('/link/token/create', fields);
    requiredString(result.link_token);
    if (connectionID) return { link_token: result.link_token, connection_id: connectionID, mode: 'update' };
    const id = randomUUID();
    await this.pool.query(`INSERT INTO nomadfi.link_attempts (id, user_id, environment, connection_id)
      VALUES ($1, $2, $3, $4)`, [id, userID, this.plaid.environment, randomUUID()]);
    return { link_token: result.link_token, attempt_id: id, mode: 'create' };
  }
  async exchange(userID, attemptID, publicToken) {
    uuid(attemptID); requiredString(publicToken, 4096);
    const inputDigest = digest(publicToken);
    const row = { id: attemptID, user_id: userID, environment: this.plaid.environment };
    const encrypted = await this.cipher.encrypt(publicToken, this.context('link-public', row));
    const attempt = await transaction(this.pool, async client => {
      const user = (await client.query('SELECT state FROM nomadfi.users WHERE id = $1 FOR UPDATE', [userID])).rows[0];
      const current = (await client.query(`SELECT *, expires_at > clock_timestamp() AS valid,
        lease_expires_at > clock_timestamp() AS busy FROM nomadfi.link_attempts
        WHERE id = $1 AND user_id = $2 FOR UPDATE`, [attemptID, userID])).rows[0];
      if (!current || user?.state !== 'active' || current.environment !== this.plaid.environment) throw new ServiceError('NOT_FOUND', 404);
      if (current.public_digest && !equalDigest(current.public_digest, inputDigest)) throw new ServiceError('EXCHANGE_CONFLICT', 409);
      if (['complete', 'exchanged'].includes(current.state)) return current;
      if (current.state === 'recovery_required') throw new ServiceError('LINK_RECOVERY_REQUIRED', 409);
      if (current.busy) throw new ServiceError('EXCHANGE_IN_PROGRESS', 409);
      if (!current.valid) throw new ServiceError('LINK_EXPIRED', 409);
      return (await client.query(`UPDATE nomadfi.link_attempts SET public_digest = $2, public_key_id = $3,
        encrypted_public = $4, state = 'exchanging', lease_epoch = lease_epoch + 1,
        lease_expires_at = clock_timestamp() + interval '2 minutes' WHERE id = $1 RETURNING *`,
      [attemptID, inputDigest, encrypted.keyID, encrypted.encryptedToken])).rows[0];
    });
    if (attempt.state === 'complete') return { connection_id: attempt.connection_id };
    if (attempt.state !== 'exchanged') {
      try {
        const result = await this.plaid.request('/item/public_token/exchange', { public_token: publicToken });
        requiredString(result.access_token); requiredString(result.item_id, 512);
        const sealed = await this.cipher.encrypt(JSON.stringify({ access_token: result.access_token, item_id: result.item_id }),
          this.context('link-result', attempt));
        const saved = await this.pool.query(`UPDATE nomadfi.link_attempts SET result_key_id = $3, encrypted_result = $4,
          state = 'exchanged', lease_expires_at = NULL, encrypted_public = NULL, public_key_id = NULL
          WHERE id = $1 AND lease_epoch = $2 AND state = 'exchanging' RETURNING id`,
        [attemptID, attempt.lease_epoch, sealed.keyID, sealed.encryptedToken]);
        if (!saved.rowCount) throw new ServiceError('EXCHANGE_IN_PROGRESS', 409);
        attempt.result_key_id = sealed.keyID; attempt.encrypted_result = sealed.encryptedToken;
      } catch (error) {
        if (error.code === 'INVALID_PUBLIC_TOKEN') {
          await this.pool.query(`UPDATE nomadfi.link_attempts SET state = 'recovery_required', lease_expires_at = NULL,
            public_key_id = NULL, encrypted_public = NULL WHERE id = $1 AND lease_epoch = $2 AND state = 'exchanging'`,
          [attemptID, attempt.lease_epoch]);
          throw new ServiceError('LINK_RECOVERY_REQUIRED', 409);
        }
        throw error;
      }
    }
    const result = JSON.parse(await this.cipher.decrypt({ keyID: attempt.result_key_id, encryptedToken: attempt.encrypted_result },
      this.context('link-result', attempt)));
    const sealed = await this.cipher.encrypt(result.access_token,
      tokenContext('plaid', userID, attempt.connection_id, attempt.environment));
    return transaction(this.pool, async client => {
      const user = (await client.query('SELECT state FROM nomadfi.users WHERE id = $1 FOR UPDATE', [userID])).rows[0];
      if (user?.state !== 'active') throw new ServiceError('ACCOUNT_DELETING', 403);
      const current = (await client.query('SELECT state FROM nomadfi.link_attempts WHERE id = $1 FOR UPDATE', [attemptID])).rows[0];
      if (current.state === 'complete') return { connection_id: attempt.connection_id };
      const conflict = await client.query('SELECT id FROM nomadfi.connections WHERE environment = $1 AND provider_item_id = $2',
        [attempt.environment, result.item_id]);
      if (conflict.rowCount) throw new ServiceError('CONNECTION_ALREADY_LINKED', 409);
      await client.query(`INSERT INTO nomadfi.connections (id, user_id, environment, provider_item_id)
        VALUES ($1, $2, $3, $4)`, [attempt.connection_id, userID, attempt.environment, result.item_id]);
      await client.query(`INSERT INTO nomadfi.credentials (connection_id, user_id, key_id, encrypted_token)
        VALUES ($1, $2, $3, $4)`, [attempt.connection_id, userID, sealed.keyID, sealed.encryptedToken]);
      await client.query('INSERT INTO nomadfi.sync_jobs (connection_id, user_id) VALUES ($1, $2)', [attempt.connection_id, userID]);
      await client.query(`UPDATE nomadfi.link_attempts SET state = 'complete', encrypted_result = NULL,
        result_key_id = NULL WHERE id = $1`, [attemptID]);
      return { connection_id: attempt.connection_id };
    });
  }
  async completeUpdate(userID, connectionID) {
    const accessToken = await this.credential(userID, connectionID);
    await this.plaid.request('/accounts/get', { access_token: accessToken });
    return transaction(this.pool, async client => {
      await client.query('SELECT id FROM nomadfi.users WHERE id = $1 FOR UPDATE', [userID]);
      const result = await client.query(`UPDATE nomadfi.connections SET state = 'connected'
        WHERE id = $1 AND user_id = $2 AND state IN ('connected', 'reconnect_required')
          AND EXISTS (SELECT 1 FROM nomadfi.users WHERE id = $2 AND state = 'active') RETURNING id`, [connectionID, userID]);
      if (!result.rowCount) throw new ServiceError('NOT_FOUND', 404);
      await client.query(`UPDATE nomadfi.sync_jobs SET requested_revision = requested_revision + 1,
        attempts = 0, dead_letter = false, failure_code = NULL, available_at = clock_timestamp()
        WHERE connection_id = $1`, [connectionID]);
      return { connection_id: connectionID };
    });
  }
}
