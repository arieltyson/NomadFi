import { transaction } from './database.js';
import { tokenContext } from './token-cipher.js';
import { ServiceError } from './security.js';
import { mapAccounts, mapTransactions } from './plaid-mapper.js';

export class SyncWorker {
  constructor({ store, plaid, cipher, clock = () => new Date() }) {
    this.store = store; this.pool = store.pool; this.plaid = plaid; this.cipher = cipher; this.clock = clock;
  }
  async runOne() {
    const claim = await this.store.claim();
    if (!claim) return { status: 'idle' };
    let generation;
    try {
      const connection = (await this.pool.query(`SELECT c.environment, k.key_id, k.encrypted_token
        FROM nomadfi.connections c JOIN nomadfi.credentials k ON k.connection_id = c.id
        WHERE c.id = $1 AND c.user_id = $2`, [claim.connection_id, claim.user_id])).rows[0];
      if (!connection || connection.environment !== this.plaid.environment) throw new ServiceError('PROVIDER_INVALID_DATA', 502);
      const accessToken = await this.cipher.decrypt({ keyID: connection.key_id, encryptedToken: connection.encrypted_token },
        tokenContext('plaid', claim.user_id, claim.connection_id, connection.environment));
      for (let restart = 0; restart < 3; restart++) {
        try {
          await this.store.renew(claim);
          const accounts = await this.plaid.request('/accounts/get', { access_token: accessToken });
          const accountEvents = mapAccounts(accounts.accounts, this.clock().toISOString());
          const activeIDs = new Set(accountEvents.map(event => event.externalID));
          const oldAccounts = await this.pool.query(`SELECT external_id FROM nomadfi.ledger_records
            WHERE connection_id = $1 AND kind = 'account' AND NOT removed`, [claim.connection_id]);
          accountEvents.push(...oldAccounts.rows.filter(row => !activeIDs.has(row.external_id))
            .map(row => ({ kind: 'removed_account', externalID: row.external_id, payload: {} })));
          generation = await this.store.beginGeneration(claim);
          let cursor = generation.cursor;
          for (let index = 0; index < 1000; index++) {
            await this.store.renew(claim);
            const page = await this.plaid.request('/transactions/sync', {
              access_token: accessToken, ...(cursor === null ? {} : { cursor }), count: 500,
            });
            const events = mapTransactions(page);
            if (index === 0) events.unshift(...accountEvents);
            await this.store.stagePage(claim, generation.id, {
              index, cursor, nextCursor: page.next_cursor, hasMore: page.has_more, events,
            });
            cursor = page.next_cursor;
            if (!page.has_more) {
              const revision = await this.store.publish(claim, generation.id);
              return { status: 'published', revision };
            }
          }
          throw new ServiceError('PROVIDER_INVALID_DATA', 502);
        } catch (error) {
          if (generation) await this.store.discard(claim, generation.id);
          generation = null;
          if (error.code !== 'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION' || restart === 2) throw error;
        }
      }
    } catch (error) {
      if (error.code === 'LEASE_LOST') return { status: 'lease_lost' };
      if (['ITEM_LOGIN_REQUIRED', 'ITEM_NOT_FOUND', 'INVALID_ACCESS_TOKEN'].includes(error.code)) {
        await transaction(this.pool, async client => {
          await client.query('SELECT id FROM nomadfi.users WHERE id = $1 FOR UPDATE', [claim.user_id]);
          await this.store.assertLease(client, claim);
          await client.query("UPDATE nomadfi.connections SET state = 'reconnect_required' WHERE id = $1", [claim.connection_id]);
          await client.query('UPDATE nomadfi.sync_jobs SET lease_expires_at = NULL WHERE connection_id = $1', [claim.connection_id]);
        });
        return { status: 'reconnect_required' };
      }
      const code = error.code === 'PROVIDER_INVALID_DATA' ? 'invalid_data' : 'upstream_unavailable';
      await this.store.fail(claim, code, Math.min(3600, 30 * 2 ** Math.min(claim.attempts, 7)));
      return { status: 'retry', code };
    }
  }
}
