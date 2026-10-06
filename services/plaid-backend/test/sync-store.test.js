import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import pg from 'pg';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate, transaction } from '../src/database.js';
import { SyncStore } from '../src/sync-store.js';

let database, pool, store, owner, other;
before(async () => {
  database = await temporaryPostgres();
  pool = database.pool;
  await migrate(pool);
  store = new SyncStore(pool);
});
after(async () => {
  await pool?.end();
  await database?.stop();
});
beforeEach(async () => {
  await pool.query('TRUNCATE nomadfi.users CASCADE');
  owner = await store.createUser(`fixture-owner-${randomUUID()}`);
  other = await store.createUser(`fixture-other-${randomUUID()}`);
});

function connection(userID = owner, providerItemID = randomUUID()) {
  return store.addConnection({
    userID, environment: 'sandbox', providerItemID, keyID: 'fixture-key',
    encryptedToken: randomBytes(64), institutionName: 'Synthetic Institution',
  });
}
function event(externalID = 'fixture-transaction', kind = 'transaction') {
  return { kind, externalID, payload: { amount: '12.34', currency: 'CAD' } };
}
async function prepare(events = [event()]) {
  const claim = await store.claim();
  const generation = await store.beginGeneration(claim);
  await store.stagePage(claim, generation.id, {
    index: 0, cursor: generation.cursor, nextCursor: randomUUID(), hasMore: false, events,
  });
  return { claim, generation };
}

test('migrations are repeatable and schema rejects cross-owner credentials', async () => {
  await migrate(pool);
  const id = await connection();
  await assert.rejects(pool.query('UPDATE nomadfi.credentials SET user_id = $2 WHERE connection_id = $1', [id, other]),
    error => error.code === '23503');
});

test('adding banks preserves existing connections and excludes credentials from discovery', async () => {
  const first = await connection();
  const second = await connection();
  assert.deepEqual(new Set((await store.connections(owner)).map(value => value.id)), new Set([first, second]));
  assert.deepEqual(await store.connections(other), []);
  assert.equal('encrypted_token' in (await store.connections(owner))[0], false);
  await assert.rejects(store.requestSync(other, first), { code: 'NOT_FOUND' });
});

test('an upstream Item cannot belong to two users', async () => {
  await connection(owner, 'fixture-shared-item');
  await assert.rejects(connection(other, 'fixture-shared-item'), error => error.code === '23505');
  assert.equal((await store.connections(other)).length, 0);
});

test('pages remain invisible and the upstream cursor stays put until publication', async () => {
  const id = await connection();
  const claim = await store.claim();
  const generation = await store.beginGeneration(claim);
  await store.stagePage(claim, generation.id, { index: 0, cursor: null, nextCursor: 'fixture-page-one', hasMore: true, events: [event()] });
  assert.deepEqual((await store.changes(owner)).events, []);
  assert.equal((await pool.query('SELECT upstream_cursor FROM nomadfi.connections WHERE id = $1', [id])).rows[0].upstream_cursor, null);
  await assert.rejects(store.publish(claim, generation.id), { code: 'INCOMPLETE_OR_PUBLISHED' });
  await store.stagePage(claim, generation.id, { index: 1, cursor: 'fixture-page-one', nextCursor: 'fixture-final', hasMore: false, events: [event('fixture-removal', 'removed_transaction')] });
  assert.equal(await store.publish(claim, generation.id), '1');
  assert.equal((await store.changes(owner)).events.length, 2);
  assert.equal((await pool.query('SELECT upstream_cursor FROM nomadfi.connections WHERE id = $1', [id])).rows[0].upstream_cursor, 'fixture-final');
  assert.equal(await store.claim(), null);
});

test('events arriving during work remain queued after that generation completes', async () => {
  const id = await connection();
  const { claim, generation } = await prepare();
  await store.requestSync(owner, id);
  await store.publish(claim, generation.id);
  const next = await store.claim();
  assert.equal(next.connection_id, id);
  assert.equal(next.leased_request_revision, '2');
});

test('concurrent claims cannot give the same connection to two workers', async () => {
  await connection();
  await connection();
  const claims = await Promise.all([store.claim(), store.claim(), store.claim()]);
  assert.equal(claims.filter(Boolean).length, 2);
  assert.equal(new Set(claims.filter(Boolean).map(value => value.connection_id)).size, 2);
});

test('expired workers are fenced out of publishing or staging', async () => {
  const id = await connection();
  const first = await prepare();
  await pool.query("UPDATE nomadfi.sync_jobs SET lease_expires_at = now() - interval '1 second' WHERE connection_id = $1", [id]);
  const replacement = await store.claim();
  assert.equal(BigInt(replacement.lease_epoch), BigInt(first.claim.lease_epoch) + 1n);
  await assert.rejects(store.publish(first.claim, first.generation.id), { code: 'LEASE_LOST' });
  await assert.rejects(store.beginGeneration(first.claim), { code: 'LEASE_LOST' });
  assert.equal((await store.changes(owner)).through, '0');
});

test('publication rolls back data visibility, user revision and cursor together on failure', async () => {
  await connection();
  const { claim, generation } = await prepare();
  await pool.query(`CREATE FUNCTION nomadfi.reject_publication() RETURNS trigger LANGUAGE plpgsql AS
    'BEGIN RAISE EXCEPTION ''synthetic rollback''; END';
    CREATE TRIGGER reject_publication BEFORE UPDATE OF upstream_cursor ON nomadfi.connections
    FOR EACH ROW EXECUTE FUNCTION nomadfi.reject_publication()`);
  try {
    await assert.rejects(store.publish(claim, generation.id));
    assert.equal((await store.changes(owner)).through, '0');
    assert.equal((await store.changes(owner)).events.length, 0);
  } finally {
    await pool.query('DROP TRIGGER reject_publication ON nomadfi.connections; DROP FUNCTION nomadfi.reject_publication()');
  }
  assert.equal(await store.publish(claim, generation.id), '1');
});

test('concurrent bank publications receive ordered user revisions without missing events', async () => {
  await connection();
  await connection();
  const first = await prepare([event('fixture-first')]);
  const second = await prepare([event('fixture-second')]);
  const revisions = await Promise.all([
    store.publish(first.claim, first.generation.id), store.publish(second.claim, second.generation.id),
  ]);
  assert.deepEqual(new Set(revisions), new Set(['1', '2']));
  const page = await store.changes(owner);
  assert.deepEqual(page.events.map(value => value.delivery_revision), ['1', '2']);
  assert.equal(page.through, '2');
});

test('bounded delivery keeps a fixed upper revision while more banks publish', async () => {
  await connection();
  const first = await prepare([event('fixture-a'), event('fixture-b'), event('fixture-c')]);
  await store.publish(first.claim, first.generation.id);
  const page = await store.changes(owner, { limit: 2 });
  assert.equal(page.hasMore, true);
  await connection();
  const second = await prepare([event('fixture-next')]);
  await store.publish(second.claim, second.generation.id);
  const remainder = await store.changes(owner, { ...page.checkpoint, through: page.through, limit: 2 });
  assert.deepEqual(remainder.events.map(value => value.external_id), ['fixture-c']);
  assert.equal(remainder.hasMore, false);
  const subsequent = await store.changes(owner, remainder.checkpoint);
  assert.deepEqual(subsequent.events.map(value => value.external_id), ['fixture-next']);
  assert.deepEqual((await store.changes(other)).events, []);
});

test('empty generations advance checkpoints without losing the next generation', async () => {
  await connection();
  const first = await prepare([]);
  await store.publish(first.claim, first.generation.id);
  const empty = await store.changes(owner);
  assert.equal(empty.checkpoint.revision, '1');
  await connection();
  const second = await prepare();
  await store.publish(second.claim, second.generation.id);
  assert.equal((await store.changes(owner, empty.checkpoint)).events.length, 1);
});

test('wrong page ordering and mismatched generation ownership cannot advance a cursor', async () => {
  await connection();
  const claim = await store.claim();
  const generation = await store.beginGeneration(claim);
  const page = { index: 1, cursor: null, nextCursor: 'fixture-next', hasMore: false, events: [] };
  await assert.rejects(store.stagePage(claim, generation.id, page), { code: 'PAGE_ORDER' });
  await assert.rejects(store.stagePage({ ...claim, user_id: other }, generation.id, { ...page, index: 0 }), { code: 'LEASE_LOST' });
  assert.equal((await store.changes(owner)).through, '0');
});

test('retry backoff isolates failures and eight failures enter dead-letter state', async () => {
  const id = await connection();
  for (let attempt = 1; attempt <= 8; attempt++) {
    const claim = await store.claim();
    await store.fail(claim, 'upstream_unavailable', 1);
    assert.equal(await store.claim(), null);
    await pool.query("UPDATE nomadfi.sync_jobs SET available_at = now() - interval '1 second' WHERE connection_id = $1", [id]);
  }
  assert.equal(await store.claim(), null);
  const healthyID = await connection();
  assert.equal((await store.claim()).connection_id, healthyID);
});

test('database server restart preserves connections and cursor state', async () => {
  await connection();
  const first = await prepare();
  await store.publish(first.claim, first.generation.id);
  await pool.end();
  await database.restart();
  pool = new pg.Pool(database.config);
  store = new SyncStore(pool);
  assert.equal((await store.connections(owner)).length, 1);
  assert.equal((await store.changes(owner)).events.length, 1);
  assert.equal(await store.claim(), null);
});

test('deleting users and disconnected connections cannot start new work', async () => {
  const id = await connection();
  await pool.query("UPDATE nomadfi.connections SET state = 'disconnected' WHERE id = $1", [id]);
  assert.equal(await store.claim(), null);
  await assert.rejects(store.requestSync(owner, id), { code: 'NOT_FOUND' });
  await pool.query("UPDATE nomadfi.users SET state = 'deleting' WHERE id = $1", [owner]);
  await assert.rejects(connection(), { code: 'NOT_FOUND' });
  await assert.rejects(store.changes(owner), { code: 'NOT_FOUND' });
});

test('transaction rollback does not leave a user revision gap', async () => {
  await assert.rejects(transaction(pool, async client => {
    await client.query('UPDATE nomadfi.users SET delivery_revision = delivery_revision + 1 WHERE id = $1', [owner]);
    throw new Error('synthetic failure');
  }));
  assert.equal((await store.changes(owner)).through, '0');
});

test('devices acknowledge independently and old retries cannot rewind checkpoints', async () => {
  await connection();
  const first = await prepare([event('fixture-a'), event('fixture-b')]);
  await store.publish(first.claim, first.generation.id);
  const firstDevice = randomUUID();
  const secondDevice = randomUUID();
  await store.acknowledge(owner, firstDevice, { revision: '1', offset: 1 });
  await store.acknowledge(owner, firstDevice, { revision: '0', offset: -1 });
  await store.acknowledge(owner, secondDevice, { revision: '1', offset: 0 });
  const rows = (await pool.query('SELECT device_id, revision, event_offset FROM nomadfi.device_checkpoints')).rows;
  assert.equal(rows.find(row => row.device_id === firstDevice).event_offset, 1);
  assert.equal(rows.find(row => row.device_id === secondDevice).event_offset, 0);
  await assert.rejects(store.acknowledge(other, firstDevice, { revision: '1', offset: 0 }), { code: 'INVALID_CHECKPOINT' });
});

test('lease renewal cannot revive an expired worker and repeated crashes stop retrying', async () => {
  const id = await connection();
  for (let index = 0; index < 8; index++) {
    const claim = await store.claim();
    assert.ok(claim);
    await store.renew(claim, 90);
    await pool.query("UPDATE nomadfi.sync_jobs SET lease_expires_at = now() - interval '1 second' WHERE connection_id = $1", [id]);
    await assert.rejects(store.renew(claim), { code: 'LEASE_LOST' });
  }
  assert.equal(await store.claim(), null);
  assert.equal((await pool.query('SELECT dead_letter FROM nomadfi.sync_jobs WHERE connection_id = $1', [id])).rows[0].dead_letter, true);
});

test('a delayed commit prevents another connection publishing a higher visible revision', async () => {
  await connection();
  await connection();
  const first = await prepare([event('fixture-delayed')]);
  const second = await prepare([event('fixture-concurrent')]);
  let releaseCommit, reachedCommit;
  const hold = new Promise(resolve => { releaseCommit = resolve; });
  const reached = new Promise(resolve => { reachedCommit = resolve; });
  const delayedStore = new SyncStore({
    async connect() {
      const client = await pool.connect();
      return {
        async query(...args) {
          if (args[0] === 'COMMIT') { reachedCommit(); await hold; }
          return client.query(...args);
        },
        release() { client.release(); },
      };
    },
  });
  const publishingFirst = delayedStore.publish(first.claim, first.generation.id);
  let publishingSecond;
  try {
    await reached;
    publishingSecond = store.publish(second.claim, second.generation.id);
    const visible = await store.changes(owner);
    assert.equal(visible.through, '0');
    assert.deepEqual(visible.events, []);
  } finally { releaseCommit(); }
  assert.deepEqual(await Promise.all([publishingFirst, publishingSecond]), ['1', '2']);
  assert.deepEqual((await store.changes(owner)).events.map(value => value.external_id), ['fixture-delayed', 'fixture-concurrent']);
});
