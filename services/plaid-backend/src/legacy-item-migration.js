import { randomUUID } from 'node:crypto';
import { requiredString, ServiceError, uuid } from './security.js';
import { tokenContext } from './token-cipher.js';

export class LegacyItemMigration {
  constructor({ pool, store, plaid, cipher, webhookURL, allowedSubjects }) {
    const url = new URL(webhookURL);
    if (url.protocol !== 'https:' || url.username || url.password || url.hash) throw new ServiceError('HTTPS_REQUIRED');
    this.pool = pool; this.store = store; this.plaid = plaid; this.cipher = cipher;
    this.webhookURL = webhookURL; this.allowedSubjects = new Set(allowedSubjects);
  }
  async run(input) {
    const userID = uuid(input.user_id), itemID = requiredString(input.expected_item_id, 512);
    const accessToken = requiredString(input.access_token, 4096);
    if (input.environment !== this.plaid.environment || !Array.isArray(input.expected_account_ids)
        || input.expected_account_ids.length === 0 || input.expected_account_ids.length > 200
        || input.expected_account_ids.some(value => typeof value !== 'string' || value.length > 512 || !value.length)
        || new Set(input.expected_account_ids).size !== input.expected_account_ids.length) throw new ServiceError('INVALID_MIGRATION_MANIFEST');
    const owner = (await this.pool.query("SELECT apple_subject FROM nomadfi.users WHERE id = $1 AND state = 'active'", [userID])).rows[0];
    if (!owner || !this.allowedSubjects.has(owner.apple_subject)) throw new ServiceError('MIGRATION_OWNER_NOT_ALLOWED', 403);
    const item = await this.plaid.request('/item/get', { access_token: accessToken });
    if (item.item?.item_id !== itemID) throw new ServiceError('MIGRATION_ITEM_MISMATCH');
    const response = await this.plaid.request('/accounts/get', { access_token: accessToken });
    if (!Array.isArray(response.accounts)) throw new ServiceError('INVALID_PROVIDER_DATA');
    const actual = response.accounts.map(account => account.account_id).sort();
    if (JSON.stringify(actual) !== JSON.stringify(input.expected_account_ids.slice().sort())) throw new ServiceError('MIGRATION_ACCOUNTS_MISMATCH');
    if (input.commit !== true) return { status: 'validated', account_count: actual.length };
    const existing = (await this.pool.query('SELECT id, user_id, state FROM nomadfi.connections WHERE environment = $1 AND provider_item_id = $2',
      [input.environment, itemID])).rows[0];
    if (existing && (existing.user_id !== userID || existing.state !== 'connected')) throw new ServiceError('MIGRATION_CONNECTION_CONFLICT', 409);
    const id = existing?.id ?? randomUUID();
    if (!existing) {
      const sealed = await this.cipher.encrypt(accessToken, tokenContext('plaid', userID, id, input.environment));
      await this.store.addConnection({ id, userID, environment: input.environment, providerItemID: itemID, ...sealed });
    }
    // Persist first: an interrupted webhook update can be retried without losing the Item or its token.
    await this.plaid.request('/item/webhook/update', { access_token: accessToken, webhook: this.webhookURL });
    await this.store.requestSync(userID, id);
    return { status: 'queued', connection_id: id, account_count: actual.length };
  }
}
