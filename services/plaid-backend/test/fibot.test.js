import { before, beforeEach, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';
import { SyncStore } from '../src/sync-store.js';
import { FiBotService, FiBotMonitor, notificationAllowed, monitorSettings } from '../src/fibot-service.js';

let database, pool, service, userID, otherID;
before(async () => { database = await temporaryPostgres(); pool = database.pool; await migrate(pool); service = new FiBotService(pool); });
after(async () => { await pool?.end(); await database?.stop(); });
beforeEach(async () => {
  await pool.query('TRUNCATE nomadfi.users CASCADE');
  const store = new SyncStore(pool); userID = await store.createUser('owner'); otherID = await store.createUser('other');
});
const now = () => new Date('2026-10-06T19:00:00Z');
const settings = () => ({ categories: ['cash_shortfall', 'stale_context'], quietStart: 22, quietEnd: 8, timeZone: 'America/Vancouver', snoozedUntil: null });
const input = () => ({ consent: true, expectedRevision: '0', context: { evaluatedOn: '2026-10-06', horizonEnd: '2027-01-04',
  accounts: [], flows: [], commitments: [], coverage: {} }, policy: { version: 'cash-flow-v1' }, settings: settings() });
const shortfall = () => ({ outcome: 'wait', reasons: ['purchase_reduces_protected_cash'], policyVersion: 'cash-flow-v1' });
const worker = evaluate => new FiBotMonitor({ pool, evaluate: evaluate ?? (async () => shortfall()), now });

test('monitoring evaluates the saved local day across UTC midnight and daylight saving', async () => {
  for (const [instant, day, timeZone] of [['2026-10-06T01:00:00Z', '2026-10-05', 'America/Vancouver'],
    ['2026-11-01T05:30:00Z', '2026-11-01', 'America/New_York'],
    ['2026-11-01T06:30:00Z', '2026-11-01', 'America/New_York']]) {
    const request = input();
    request.context.evaluatedOn = day;
    request.settings.timeZone = timeZone;
    request.context.flows = [{ date: day }, { date: '2026-10-04' }];
    request.context.coverage.accountsComplete = true;
    await service.configure(userID, request);
    const result = await new FiBotMonitor({ pool, now: () => new Date(instant), evaluate: async ({ context }) => {
      assert.equal(context.evaluatedOn, day);
      assert.equal(context.coverage.accountsComplete, true);
      assert.deepEqual(context.flows, [{ date: day }]);
      return shortfall();
    } }).runOne();
    assert.equal(result.status, 'evaluated');
    await service.configure(userID, { consent: false });
  }
});

test('monitoring requires explicit consent, isolates owners and deletes all uploaded context on opt-out', async () => {
  await assert.rejects(service.configure(userID, { ...input(), consent: undefined }), { code: 'MONITOR_CONSENT_REQUIRED' });
  await service.configure(userID, input()); await worker().runOne();
  assert.equal((await service.status(userID)).alerts.length, 1);
  assert.equal((await service.status(otherID)).enabled, false);
  await assert.rejects(service.configure(userID, input()), { code: 'MONITOR_PLAN_CHANGED' });
  await service.configure(userID, { consent: false });
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.fibot_jobs')).rows[0].count, '0');
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.fibot_alerts')).rows[0].count, '0');
});

test('replay deduplicates alerts and dismissal does not leak or get undone', async () => {
  await service.configure(userID, input()); await worker().runOne();
  const alert = (await service.status(userID)).alerts[0];
  await service.dismiss(otherID, alert.id); assert.equal((await service.status(userID)).alerts.length, 1);
  await service.dismiss(userID, alert.id);
  await pool.query('UPDATE nomadfi.fibot_jobs SET requested_revision = requested_revision + 1');
  await worker().runOne();
  assert.equal((await pool.query('SELECT count(*) FROM nomadfi.fibot_alerts')).rows[0].count, '1');
  assert.equal((await service.status(userID)).alerts.length, 0);
});

test('a bank update invalidates uploaded manual cash and earlier advice', async () => {
  await service.configure(userID, input()); await worker().runOne();
  await pool.query('UPDATE nomadfi.fibot_profiles SET bank_revision = 1');
  await pool.query('UPDATE nomadfi.fibot_jobs SET requested_revision = requested_revision + 1');
  await worker(async ({ context }) => {
    assert.equal(context.coverage.accountsComplete, false);
    return { outcome: 'needsMoreInformation', reasons: ['confirm_all_accounts_and_shared_funds'], policyVersion: 'cash-flow-v1' };
  }).runOne();
  assert.deepEqual((await service.status(userID)).alerts.map(row => row.category), ['stale_context']);
});

test('disabling consent during computation cannot publish a late alert', async () => {
  await service.configure(userID, input());
  const result = await worker(async () => { await service.configure(userID, { consent: false }); return shortfall(); }).runOne();
  assert.equal(result.status, 'obsolete'); assert.equal((await service.status(userID)).alerts.length, 0);
});

test('account deletion immediately stops monitoring even while provider revocation is pending', async () => {
  await service.configure(userID, input());
  await pool.query("UPDATE nomadfi.users SET state = 'deleting' WHERE id = $1", [userID]);
  assert.equal((await service.status(userID)).enabled, false); assert.equal((await worker().runOne()).status, 'idle');
});

test('quiet hours, snooze and category controls suppress notification eligibility', async () => {
  assert.equal(notificationAllowed(settings(), new Date('2026-10-06T06:00:00Z')), false);
  assert.equal(notificationAllowed(settings(), now()), true);
  assert.equal(notificationAllowed({ ...settings(), snoozedUntil: '2026-10-07T00:00:00Z' }, now()), false);
  assert.throws(() => monitorSettings({ ...settings(), timeZone: 'not-a-zone' }));
  await service.configure(userID, { ...input(), settings: { ...settings(), categories: [] } });
  await worker().runOne(); assert.equal((await service.status(userID)).alerts.length, 0);
});

test('worker role can evaluate jobs but cannot change a plan or read credentials', async () => {
  await service.configure(userID, input());
  await pool.query(await readFile(new URL('../ops/roles.sql', import.meta.url), 'utf8'));
  const client = await pool.connect();
  try {
    await client.query('SET ROLE nomadfi_fibot');
    const restrictedPool = { query: (...args) => client.query(...args), async connect() {
      return { query: (...args) => client.query(...args), release() {} };
    } };
    assert.equal((await new FiBotMonitor({ pool: restrictedPool, evaluate: async () => shortfall(), now }).runOne()).status, 'evaluated');
    for (const table of ['credentials', 'apple_grants', 'sessions', 'users']) {
      await assert.rejects(client.query(`SELECT * FROM nomadfi.${table}`), { code: '42501' });
    }
    await assert.rejects(client.query('UPDATE nomadfi.fibot_profiles SET revision = revision + 1'), { code: '42501' });
  } finally { await client.query('RESET ROLE'); client.release(); }
});

test('engine failure retries with bounded attempts and never publishes optimistic advice', async () => {
  await service.configure(userID, input());
  const broken = worker(async () => { throw new Error('fixture'); });
  for (let i = 0; i < 8; i++) {
    await pool.query('UPDATE nomadfi.fibot_jobs SET available_at = clock_timestamp()');
    assert.equal((await broken.runOne()).status, 'retry');
  }
  assert.equal((await pool.query('SELECT dead_letter FROM nomadfi.fibot_jobs')).rows[0].dead_letter, true);
  assert.equal((await service.status(userID)).alerts.length, 0);
});
