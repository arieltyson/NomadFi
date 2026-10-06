import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';
import { SyncStore } from '../src/sync-store.js';
import { SyncWorker } from '../src/sync-worker.js';
import { LocalTokenCipher, tokenContext } from '../src/token-cipher.js';
import { ServiceError } from '../src/security.js';

let database, pool, store, cipher, userID, connectionID, worker, pages, cursors, accounts;
const account = { account_id: 'fixture-account', name: 'Synthetic chequing', type: 'depository', subtype: 'checking',
  balances: { current: 1200.12, available: 1100.12, iso_currency_code: 'CAD' } };
const tx = (id, extra = {}) => ({ transaction_id: id, account_id: account.account_id, name: 'Synthetic purchase',
  amount: 12.34, iso_currency_code: 'CAD', date: '2026-10-01', pending: false, ...extra });
const page = (added, next_cursor, has_more = false, extra = {}) => ({ added, modified: [], removed: [], next_cursor, has_more, ...extra });
before(async () => {
  database = await temporaryPostgres(); pool = database.pool; await migrate(pool);
  store = new SyncStore(pool); cipher = new LocalTokenCipher(randomBytes(32));
});
after(async () => { await pool?.end(); await database?.stop(); });
beforeEach(async () => {
  await pool.query('TRUNCATE nomadfi.users CASCADE');
  userID = await store.createUser('fixture-worker'); connectionID = randomUUID();
  const encrypted = await cipher.encrypt(randomBytes(32).toString('base64url'), tokenContext('plaid', userID, connectionID, 'sandbox'));
  await store.addConnection({ id: connectionID, userID, environment: 'sandbox', providerItemID: 'fixture-item', ...encrypted });
  pages = []; cursors = []; accounts = [account];
  worker = new SyncWorker({ store, cipher, plaid: { environment: 'sandbox', async request(path, fields) {
    if (path === '/accounts/get') return { accounts };
    assert.equal(path, '/transactions/sync'); cursors.push(fields.cursor ?? null);
    const value = pages.shift();
    if (value instanceof Error) throw value;
    return value;
  } } });
});
const rows = async () => (await pool.query('SELECT * FROM nomadfi.ledger_records ORDER BY kind, external_id')).rows;

test('worker publishes cached balances and pending-to-posted removal without duplicates', async () => {
  pages.push(page([tx('pending', { pending: true })], 'one'));
  assert.equal((await worker.runOne()).status, 'published');
  await store.requestSync(userID, connectionID);
  pages.push(page([tx('posted', { pending_transaction_id: 'pending' })], 'two', false,
    { removed: [{ transaction_id: 'pending' }] }));
  await worker.runOne();
  const records = await rows();
  assert.equal(records.length, 3);
  assert.equal(records[0].payload.current, '1200.12');
  assert.equal(records[0].payload.balance_observed_at, null);
  assert.equal(records[1].removed, true);
  assert.equal(records[2].payload.pending_transaction_id, 'pending');
  assert.deepEqual(cursors, [null, 'one']);
});

test('pagination mutation discards every staged page and restarts from committed cursor', async () => {
  pages.push(page([tx('discarded')], 'temporary', true), new ServiceError('TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION'),
    page([tx('correct')], 'complete'));
  assert.equal((await worker.runOne()).status, 'published');
  assert.deepEqual(cursors, [null, 'temporary', null]);
  assert.deepEqual((await rows()).map(row => row.external_id), ['fixture-account', 'correct']);
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.sync_generations')).rows[0].count, '1');
});

test('network failure after a page never advances cursor or materializes partial records', async () => {
  pages.push(page([tx('incomplete')], 'temporary', true), new ServiceError('PLAID_UNAVAILABLE'));
  assert.equal((await worker.runOne()).status, 'retry');
  assert.deepEqual(await rows(), []);
  assert.equal((await pool.query('SELECT upstream_cursor FROM nomadfi.connections')).rows[0].upstream_cursor, null);
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.sync_generations')).rows[0].count, '0');
});

test('one bank needing login does not block a second connection', async () => {
  pages.push(new ServiceError('ITEM_LOGIN_REQUIRED'));
  assert.equal((await worker.runOne()).status, 'reconnect_required');
  const nextID = randomUUID();
  await store.addConnection({ id: nextID, userID, environment: 'sandbox', providerItemID: 'second-item',
    ...await cipher.encrypt(randomBytes(32).toString('hex'), tokenContext('plaid', userID, nextID, 'sandbox')) });
  pages.push(page([tx('second')], 'second-done'));
  assert.equal((await worker.runOne()).status, 'published');
  assert.equal((await store.connections(userID)).length, 2);
});

test('modified records replace previous values and account removal creates a tombstone', async () => {
  pages.push(page([tx('existing')], 'one'));
  await worker.runOne(); await store.requestSync(userID, connectionID); accounts = [];
  pages.push(page([], 'two', false, { modified: [tx('existing', { amount: 56.78 })] }));
  await worker.runOne();
  const records = await rows();
  assert.equal(records.length, 2); assert.equal(records[0].removed, true);
  assert.equal(records[1].payload.amount, '56.78');
});

test('invalid monetary values cannot publish a generation', async () => {
  pages.push(page([tx('bad', { amount: Infinity })], 'invalid'));
  assert.equal((await worker.runOne()).code, 'invalid_data');
  assert.deepEqual(await rows(), []);
});
