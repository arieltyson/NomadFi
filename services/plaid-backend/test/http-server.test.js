import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';
import { createAPI } from '../src/http-server.js';
import { ServiceError } from '../src/security.js';

let database, pool, server, origin, token, seen, logged;
const owner = randomUUID();
before(async () => {
  database = await temporaryPostgres(); pool = database.pool; await migrate(pool);
  token = randomBytes(32).toString('base64url'); seen = []; logged = [];
  server = createAPI({ pool, rateKey: randomBytes(32), logger: entry => logged.push(entry),
    auth: { async authenticate(value) {
      if (value !== token) throw new ServiceError('SESSION_INVALID', 401);
      return { id: randomUUID(), user_id: owner };
    }, async challenge() { return { nonce: 'fixture' }; } },
    store: { async connections(user) { seen.push(user); return []; },
      async requestSync() { throw new Error('private upstream details must never be returned'); } },
    revocation: { async deleteAccount(user) { seen.push(user); return { status: 'deleting' }; } },
    webhooks: { async receive(raw) { seen.push(raw.toString()); throw new ServiceError('WEBHOOK_INVALID', 401); } },
  });
  server.listen(0, '127.0.0.1'); await once(server, 'listening'); origin = `http://127.0.0.1:${server.address().port}`;
});
after(async () => { await new Promise(resolve => server?.close(resolve)); await pool?.end(); await database?.stop(); });
function request(path, { method = 'GET', body, authenticated = true } = {}) {
  return fetch(`${origin}${path}`, { method, headers: { 'Content-Type': 'application/json',
    ...(authenticated ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
}

test('financial routes require a session and derive owner from it rather than client input', async () => {
  assert.equal((await request('/connections', { authenticated: false })).status, 401);
  const result = await request(`/connections?user_id=${randomUUID()}`);
  assert.equal(result.status, 200); assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.equal(seen.at(-1), owner);
  const deletion = await request('/account', { method: 'DELETE', body: { user_id: randomUUID() } });
  assert.equal(deletion.status, 202); assert.equal(seen.at(-1), owner);
});

test('unexpected errors are redacted in both responses and application diagnostics', async () => {
  const result = await request(`/connections/${randomUUID()}/sync`, { method: 'POST', body: {} });
  assert.equal(result.status, 500); assert.equal((await result.json()).error, 'INTERNAL_ERROR');
  assert.equal(JSON.stringify(logged).includes('private upstream details'), false);
  assert.equal(JSON.stringify(logged).includes(token), false);
});

test('webhook signature validation receives exact bytes before JSON parsing', async () => {
  const raw = '{  "fixture":true }\n';
  const result = await fetch(`${origin}/webhooks/plaid`, { method: 'POST', body: raw });
  assert.equal(result.status, 401); assert.equal(seen.at(-1), raw);
});

test('invalid JSON and excessive authentication traffic are rejected', async () => {
  const malformed = await fetch(`${origin}/auth/challenge`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '[' });
  assert.equal(malformed.status, 400);
  for (let index = 0; index < 20; index++) {
    assert.equal((await request('/auth/challenge', { method: 'POST', body: {}, authenticated: false })).status, 200);
  }
  assert.equal((await request('/auth/challenge', { method: 'POST', body: {}, authenticated: false })).status, 429);
});

test('queued webhooks and new links start the worker; Plaid only sees an acknowledgment', async () => {
  let triggered = 0;
  const api = createAPI({ pool, rateKey: randomBytes(32),
    auth: { async authenticate() { return { id: randomUUID(), user_id: owner }; } },
    link: { async exchange() { return { connection_id: randomUUID() }; } },
    webhooks: { async receive() { return { accepted: true, queued: true }; } },
    workerTrigger: { async request() { triggered += 1; return 'started'; } },
  });
  api.listen(0, '127.0.0.1'); await once(api, 'listening');
  const base = `http://127.0.0.1:${api.address().port}`;
  try {
    const webhook = await fetch(`${base}/webhooks/plaid`, { method: 'POST', body: '{}' });
    assert.equal(webhook.status, 200); assert.deepEqual(await webhook.json(), { accepted: true });
    const exchange = await fetch(`${base}/link/exchange`, { method: 'POST', headers: { 'Content-Type': 'application/json',
      Authorization: `Bearer ${randomBytes(32).toString('base64url')}` }, body: JSON.stringify({ attempt_id: randomUUID(), public_token: 'public-sandbox-x' }) });
    assert.equal(exchange.status, 200);
    assert.equal(triggered, 2);
  } finally { await new Promise(resolve => api.close(resolve)); }
});
