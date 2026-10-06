import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';
import { SyncStore } from '../src/sync-store.js';
import { LocalTokenCipher } from '../src/token-cipher.js';
import { LegacyItemMigration } from '../src/legacy-item-migration.js';

let database, pool, store, migration, userID, input, failWebhook, calls;
before(async () => { database = await temporaryPostgres(); pool = database.pool; await migrate(pool); store = new SyncStore(pool); });
after(async () => { await pool?.end(); await database?.stop(); });
beforeEach(async () => {
  await pool.query('TRUNCATE nomadfi.users CASCADE'); userID = await store.createUser('allowed-owner'); failWebhook = false; calls = [];
  input = { user_id: userID, environment: 'sandbox', access_token: randomBytes(32).toString('hex'),
    expected_item_id: 'synthetic-item', expected_account_ids: ['synthetic-account'] };
  migration = new LegacyItemMigration({ pool, store, cipher: new LocalTokenCipher(randomBytes(32)),
    webhookURL: 'https://example.test/webhooks/plaid', allowedSubjects: ['allowed-owner'],
    plaid: { environment: 'sandbox', async request(path) {
      calls.push(path);
      if (path === '/item/get') return { item: { item_id: 'synthetic-item' } };
      if (path === '/accounts/get') return { accounts: [{ account_id: 'synthetic-account' }] };
      if (failWebhook) throw new Error('synthetic outage');
      return {};
    } } });
});
test('preview validates exact provider identities without storing or changing bank authorization', async () => {
  assert.deepEqual(await migration.run(input), { status: 'validated', account_count: 1 });
  assert.equal((await store.connections(userID)).length, 0);
  assert.equal(calls.includes('/item/webhook/update'), false);
  await assert.rejects(migration.run({ ...input, expected_account_ids: ['wrong'] }), { code: 'MIGRATION_ACCOUNTS_MISMATCH' });
  await assert.rejects(migration.run({ ...input, environment: 'production' }), { code: 'INVALID_MIGRATION_MANIFEST' });
});
test('committed migration persists encrypted credentials before webhook changes and is retryable', async () => {
  failWebhook = true;
  await assert.rejects(migration.run({ ...input, commit: true }));
  assert.equal((await store.connections(userID)).length, 1);
  failWebhook = false;
  const result = await migration.run({ ...input, commit: true });
  assert.equal(result.status, 'queued'); assert.equal((await store.connections(userID)).length, 1);
  const encrypted = (await pool.query('SELECT encrypted_token FROM nomadfi.credentials')).rows[0].encrypted_token;
  assert.equal(encrypted.includes(Buffer.from(input.access_token)), false);
});
test('a different or unapproved owner cannot adopt a bank Item', async () => {
  const other = await store.createUser('not-allowed');
  await assert.rejects(migration.run({ ...input, user_id: other, commit: true }), { code: 'MIGRATION_OWNER_NOT_ALLOWED' });
  assert.equal(calls.length, 0);
});
