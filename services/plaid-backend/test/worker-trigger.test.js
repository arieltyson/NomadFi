import { test } from 'node:test';
import assert from 'node:assert/strict';
import { WorkerTrigger } from '../src/worker-trigger.js';

const job = 'projects/nomadfi-sandbox-482096/locations/northamerica-northeast1/jobs/nomadfi-worker';
function upstream({ tokenStatus = 200, runStatus = 200 } = {}) {
  const calls = [];
  const fetch = async (url, init) => {
    calls.push({ url, init });
    if (url.startsWith('http://metadata.google.internal/')) {
      return { ok: tokenStatus === 200, status: tokenStatus, json: async () => ({ access_token: 'synthetic-token' }) };
    }
    return { ok: runStatus === 200, status: runStatus, json: async () => ({}) };
  };
  return { fetch, calls };
}

test('starts the configured job with the service identity token', async () => {
  const { fetch, calls } = upstream();
  assert.equal(await new WorkerTrigger({ jobName: job, fetch }).request(), 'started');
  assert.equal(calls[0].init.headers['Metadata-Flavor'], 'Google');
  assert.equal(calls[1].url, `https://run.googleapis.com/v2/${job}:run`);
  assert.equal(calls[1].init.method, 'POST');
  assert.equal(calls[1].init.headers.Authorization, 'Bearer synthetic-token');
});

test('a burst of requests shares one execution, and a later one starts another', async () => {
  const { fetch, calls } = upstream(); let now = 0;
  const trigger = new WorkerTrigger({ jobName: job, fetch, clock: () => now, coalesceMs: 5000 });
  assert.equal(await trigger.request(), 'started');
  now = 4999; assert.equal(await trigger.request(), 'coalesced');
  now = 5000; assert.equal(await trigger.request(), 'started');
  assert.equal(calls.filter(call => call.url.includes(':run')).length, 2);
});

test('failures never throw and do not suppress the next attempt', async () => {
  const logged = []; let now = 0;
  const failing = upstream({ runStatus: 403 });
  const trigger = new WorkerTrigger({ jobName: job, fetch: failing.fetch, clock: () => now, logger: entry => logged.push(entry) });
  assert.equal(await trigger.request(), 'failed');
  assert.deepEqual(logged.at(-1), { event: 'worker_trigger_failed', reason: 'run 403' });
  now = 1; assert.equal(await trigger.request(), 'failed', 'a failed start is retried, not coalesced');
  const offline = new WorkerTrigger({ jobName: job, fetch: async () => { throw new TypeError('fetch failed'); } });
  assert.equal(await offline.request(), 'failed');
});

test('does nothing without a job, and rejects a malformed job name', async () => {
  const { fetch, calls } = upstream();
  assert.equal(await new WorkerTrigger({ fetch }).request(), 'disabled');
  assert.equal(calls.length, 0);
  assert.throws(() => new WorkerTrigger({ jobName: 'https://evil.example/jobs/x' }));
});

test('a slow upstream is abandoned within the timeout', async () => {
  const hanging = (url, { signal }) => new Promise((_, reject) => signal.addEventListener('abort', () => reject(signal.reason)));
  const started = Date.now();
  // AbortSignal.timeout uses an unref'd timer; keep the loop alive until it fires.
  const keepAlive = setTimeout(() => {}, 5000);
  try {
    assert.equal(await new WorkerTrigger({ jobName: job, fetch: hanging, timeoutMs: 50 }).request(), 'failed');
  } finally { clearTimeout(keepAlive); }
  assert.ok(Date.now() - started < 1000);
});
