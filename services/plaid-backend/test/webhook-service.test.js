import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';
import { SyncStore } from '../src/sync-store.js';
import { WebhookService, enqueueStaleConnections } from '../src/webhook-service.js';
import { digest } from '../src/security.js';

let database, pool, store, userID, connectionID, service, keys, jwk;
const raw = Buffer.from(JSON.stringify({ environment: 'sandbox', item_id: 'fixture-item',
  webhook_type: 'TRANSACTIONS', webhook_code: 'SYNC_UPDATES_AVAILABLE' }));
const sign = async (body = raw, age = 0, pair = keys) => new SignJWT({ request_body_sha256: digest(body).toString('hex') })
  .setProtectedHeader({ alg: 'ES256', kid: 'fixture-key' }).setIssuedAt(Math.floor(Date.now() / 1000) - age).sign(pair.privateKey);
before(async () => {
  database = await temporaryPostgres(); pool = database.pool; await migrate(pool); store = new SyncStore(pool);
  keys = await generateKeyPair('ES256'); jwk = { ...await exportJWK(keys.publicKey), kid: 'fixture-key', alg: 'ES256', expired_at: null };
});
after(async () => { await pool?.end(); await database?.stop(); });
beforeEach(async () => {
  await pool.query('TRUNCATE nomadfi.users, nomadfi.webhook_receipts CASCADE');
  userID = await store.createUser('webhook-owner');
  connectionID = await store.addConnection({ userID, environment: 'sandbox', providerItemID: 'fixture-item',
    keyID: 'test-key', encryptedToken: randomBytes(48) });
  service = new WebhookService({ pool, plaid: { environment: 'sandbox', async request() { return { key: jwk }; } } });
});

test('verified raw-body webhook enqueues durably and duplicate delivery is idempotent', async () => {
  const token = await sign(); await service.receive(raw, token); await service.receive(raw, token);
  assert.equal((await pool.query('SELECT requested_revision FROM nomadfi.sync_jobs')).rows[0].requested_revision, '2');
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.webhook_receipts')).rows[0].count, '1');
});

test('changed body, stale/future token, wrong signature and wrong environment fail closed', async () => {
  await assert.rejects(service.receive(Buffer.concat([raw, Buffer.from(' ')]), await sign()), { code: 'WEBHOOK_INVALID' });
  for (const age of [600, -60]) await assert.rejects(service.receive(raw, await sign(raw, age)), { code: 'WEBHOOK_INVALID' });
  await assert.rejects(service.receive(raw, await sign(raw, 0, await generateKeyPair('ES256'))), { code: 'WEBHOOK_INVALID' });
  const other = Buffer.from(raw.toString().replace('sandbox', 'production'));
  await assert.rejects(service.receive(other, await sign(other)), { code: 'WEBHOOK_INVALID' });
  assert.equal((await pool.query('SELECT requested_revision FROM nomadfi.sync_jobs')).rows[0].requested_revision, '1');
});

test('failed enqueue rolls back its receipt so upstream retry remains deliverable', async () => {
  await pool.query(`CREATE FUNCTION nomadfi.reject_job() RETURNS trigger LANGUAGE plpgsql AS
    'BEGIN RAISE EXCEPTION ''fixture failure''; END';
    CREATE TRIGGER reject_job BEFORE UPDATE ON nomadfi.sync_jobs FOR EACH ROW EXECUTE FUNCTION nomadfi.reject_job()`);
  const token = await sign();
  try { await assert.rejects(service.receive(raw, token)); }
  finally { await pool.query('DROP TRIGGER reject_job ON nomadfi.sync_jobs; DROP FUNCTION nomadfi.reject_job()'); }
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.webhook_receipts')).rows[0].count, '0');
  await service.receive(raw, token);
  assert.equal((await pool.query('SELECT requested_revision FROM nomadfi.sync_jobs')).rows[0].requested_revision, '2');
});

test('scheduled catch-up coalesces pending work and excludes disconnected banks', async () => {
  assert.equal(await enqueueStaleConnections(pool), 0);
  await pool.query('UPDATE nomadfi.sync_jobs SET completed_revision = requested_revision');
  assert.equal(await enqueueStaleConnections(pool), 1);
  assert.equal(await enqueueStaleConnections(pool), 0);
  await pool.query("UPDATE nomadfi.connections SET state = 'disconnected' WHERE id = $1", [connectionID]);
  await pool.query('UPDATE nomadfi.sync_jobs SET completed_revision = requested_revision');
  assert.equal(await enqueueStaleConnections(pool), 0);
});
