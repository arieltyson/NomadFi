import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';
import { SyncStore } from '../src/sync-store.js';
import { LocalTokenCipher } from '../src/token-cipher.js';
import { LinkService } from '../src/link-service.js';
import { DeliveryService } from '../src/delivery-service.js';
import { RevocationService } from '../src/revocation-service.js';
import { ServiceError } from '../src/security.js';
import { AppleNotifications } from '../src/apple-notifications.js';

let database, pool, store, cipher, link, delivery, revocation, userID, otherID, calls, upstreamError, upstreamItem;
before(async () => { database = await temporaryPostgres(); pool = database.pool; await migrate(pool); store = new SyncStore(pool); });
after(async () => { await pool?.end(); await database?.stop(); });
beforeEach(async () => {
  await pool.query('TRUNCATE nomadfi.users CASCADE');
  userID = await store.createUser('owner'); otherID = await store.createUser('other');
  cipher = new LocalTokenCipher(randomBytes(32)); calls = []; upstreamError = null; upstreamItem = 'fixture-item';
  const plaid = { environment: 'sandbox', async request(path, fields) {
    calls.push({ path, fields });
    if (upstreamError) throw upstreamError;
    if (path === '/link/token/create') return { link_token: 'synthetic-link-token' };
    if (path === '/item/public_token/exchange') return { item_id: upstreamItem, access_token: randomBytes(32).toString('hex') };
    return { accounts: [] };
  } };
  link = new LinkService({ pool, cipher, plaid, redirectURI: 'https://example.test/oauth', webhookURL: 'https://example.test/webhook' });
  delivery = new DeliveryService(pool);
  revocation = new RevocationService({ pool, cipher, plaid, apple: { async revoke() {} } });
});
async function connect() {
  const attempt = await link.begin(userID);
  return { ...attempt, ...await link.exchange(userID, attempt.attempt_id, 'synthetic-public-token') };
}
async function publish(id, value) {
  const claim = await store.claim(); assert.equal(claim.connection_id, id);
  const gen = await store.beginGeneration(claim);
  await store.stagePage(claim, gen.id, { index: 0, cursor: gen.cursor, nextCursor: value, hasMore: false,
    events: [{ kind: 'account', externalID: 'synthetic-account', payload: { current: value } }] });
  return store.publish(claim, gen.id);
}

test('Link starts with CA/US Transactions and retrying exchange does not duplicate a connection', async () => {
  const first = await connect();
  assert.deepEqual(calls[0].fields.country_codes, ['CA', 'US']);
  assert.deepEqual(calls[0].fields.products, ['transactions']);
  assert.deepEqual(await link.exchange(userID, first.attempt_id, 'synthetic-public-token'), { connection_id: first.connection_id });
  assert.equal(calls.filter(call => call.path === '/item/public_token/exchange').length, 1);
  await assert.rejects(link.exchange(userID, first.attempt_id, 'different'), { code: 'EXCHANGE_CONFLICT' });
  await assert.rejects(link.exchange(otherID, first.attempt_id, 'synthetic-public-token'), { code: 'NOT_FOUND' });
  assert.equal((await store.connections(userID)).length, 1);
});

test('a saved exchange receipt survives attachment rollback without another upstream exchange', async () => {
  const attempt = await link.begin(userID);
  await pool.query(`CREATE FUNCTION nomadfi.reject_connection() RETURNS trigger LANGUAGE plpgsql AS
    'BEGIN RAISE EXCEPTION ''fixture failure''; END';
    CREATE TRIGGER reject_connection BEFORE INSERT ON nomadfi.connections FOR EACH ROW EXECUTE FUNCTION nomadfi.reject_connection()`);
  try { await assert.rejects(link.exchange(userID, attempt.attempt_id, 'synthetic-public-token')); }
  finally { await pool.query('DROP TRIGGER reject_connection ON nomadfi.connections; DROP FUNCTION nomadfi.reject_connection()'); }
  assert.equal((await pool.query('SELECT state FROM nomadfi.link_attempts')).rows[0].state, 'exchanged');
  await link.exchange(userID, attempt.attempt_id, 'synthetic-public-token');
  assert.equal(calls.filter(call => call.path === '/item/public_token/exchange').length, 1);
  assert.equal((await pool.query('SELECT encrypted_result FROM nomadfi.link_attempts')).rows[0].encrypted_result, null);
});

test('consumed public tokens require explicit recovery and cannot claim successful attachment', async () => {
  const attempt = await link.begin(userID); upstreamError = new ServiceError('INVALID_PUBLIC_TOKEN');
  await assert.rejects(link.exchange(userID, attempt.attempt_id, 'synthetic-public-token'), { code: 'LINK_RECOVERY_REQUIRED' });
  assert.deepEqual(await store.connections(userID), []);
  assert.equal((await pool.query('SELECT state FROM nomadfi.link_attempts')).rows[0].state, 'recovery_required');
});

test('update mode retains connection and cursor while allowing account selection', async () => {
  const first = await connect(); await publish(first.connection_id, '100');
  await pool.query("UPDATE nomadfi.connections SET state = 'reconnect_required'");
  const updated = await link.begin(userID, first.connection_id);
  assert.equal(updated.mode, 'update'); assert.equal(calls.at(-1).fields.products, undefined);
  assert.equal(calls.at(-1).fields.update.account_selection_enabled, true);
  await link.completeUpdate(userID, first.connection_id);
  assert.equal((await pool.query('SELECT upstream_cursor FROM nomadfi.connections')).rows[0].upstream_cursor, '100');
  assert.equal((await store.connections(userID)).length, 1);
  await assert.rejects(link.begin(otherID, first.connection_id), { code: 'NOT_FOUND' });
});

test('bootstrap snapshot stays frozen while later generations publish', async () => {
  const first = await connect(); const revision = await publish(first.connection_id, '100');
  const snapshot = await delivery.begin(userID);
  await store.requestSync(userID, first.connection_id); await publish(first.connection_id, '200');
  const page = await delivery.page(userID, snapshot.snapshot_id);
  assert.equal(page.records[0].payload.current, '100'); assert.equal(page.checkpoint.revision, revision);
  assert.equal((await store.changes(userID, page.checkpoint)).events[0].payload.current, '200');
  await assert.rejects(delivery.page(otherID, snapshot.snapshot_id), { code: 'SNAPSHOT_EXPIRED' });
  await pool.query("UPDATE nomadfi.snapshots SET expires_at = now() - interval '1 second'");
  await assert.rejects(delivery.page(userID, snapshot.snapshot_id), { code: 'SNAPSHOT_EXPIRED' });
});

test('disconnect stops work immediately and only drops credentials after upstream revocation', async () => {
  const first = await connect();
  await assert.rejects(revocation.disconnect(otherID, first.connection_id), { code: 'NOT_FOUND' });
  await revocation.disconnect(userID, first.connection_id);
  assert.equal(await store.claim(), null);
  upstreamError = new ServiceError('PLAID_UNAVAILABLE');
  assert.equal((await revocation.runOne()).status, 'retry');
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.credentials')).rows[0].count, '1');
  upstreamError = null; await pool.query('UPDATE nomadfi.revocation_jobs SET available_at = now()');
  assert.equal((await revocation.runOne()).status, 'revoked');
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.credentials')).rows[0].count, '0');
  assert.equal((await store.connections(userID))[0].state, 'disconnected');
});

test('account deletion waits for revocation and cascades stored financial data', async () => {
  const first = await connect(); await publish(first.connection_id, '100');
  await revocation.deleteAccount(userID);
  assert.deepEqual(await store.connections(userID), []);
  await revocation.runOne();
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.users WHERE id = $1', [userID])).rows[0].count, '0');
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.ledger_records')).rows[0].count, '0');
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.users WHERE id = $1', [otherID])).rows[0].count, '1');
});

test('ambiguous in-flight exchange prevents falsely reporting account data purged', async () => {
  const attempt = await link.begin(userID);
  upstreamError = new ServiceError('INVALID_PUBLIC_TOKEN');
  await assert.rejects(link.exchange(userID, attempt.attempt_id, 'synthetic-public-token'));
  await revocation.deleteAccount(userID); await revocation.purgeCompletedDeletions();
  assert.equal((await pool.query('SELECT state FROM nomadfi.users WHERE id = $1', [userID])).rows[0].state, 'deleting');
});

test('Apple account deletion disables the account and queues upstream removal exactly once', async () => {
  await connect();
  const service = new AppleNotifications({ pool, revocation, apple: { async verifyNotification() {
    return { id: 'fixture-deletion-event', subject: 'owner', type: 'account-deleted', time: new Date() };
  } } });
  await service.receive('verified-fixture'); await service.receive('verified-fixture');
  assert.equal((await pool.query('SELECT state FROM nomadfi.users WHERE id = $1', [userID])).rows[0].state, 'deleting');
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.revocation_jobs')).rows[0].count, '1');
  await revocation.runOne();
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.users WHERE id = $1', [userID])).rows[0].count, '0');
});

test('consent revocation suspends bank sync and old notifications cannot delete a recreated account', async () => {
  await connect();
  let event = { id: 'fixture-consent-event', subject: 'owner', type: 'consent-revoked', time: new Date() };
  const service = new AppleNotifications({ pool, revocation, apple: { async verifyNotification() { return event; } } });
  await service.receive('verified-fixture');
  assert.equal(await store.claim(), null);
  assert.equal((await store.connections(userID))[0].state, 'reconnect_required');
  event = { ...event, id: 'fixture-old-deletion', type: 'account-deleted', time: new Date(Date.now() - 60000) };
  await service.receive('verified-fixture');
  assert.equal((await pool.query('SELECT state FROM nomadfi.users WHERE id = $1', [userID])).rows[0].state, 'active');
});
