import { createServer } from 'node:http';
import { createHmac, randomUUID } from 'node:crypto';
import { ServiceError, uuid } from './security.js';
import { StoreError } from './sync-store.js';

async function body(request, maximum = 32768) {
  let size = 0; const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maximum) throw new ServiceError('BODY_TOO_LARGE', 413);
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}
function object(raw) {
  try {
    const parsed = JSON.parse(raw.toString('utf8'));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error();
    return parsed;
  } catch { throw new ServiceError('INVALID_JSON'); }
}
export function createAPI({ pool, auth, store, link, delivery, revocation, webhooks, rateKey, logger = () => {} }) {
  if (!Buffer.isBuffer(rateKey) || rateKey.length < 32) throw new ServiceError('INVALID_RATE_KEY');
  const rate = async (identity, group, maximum) => {
    const key = createHmac('sha256', rateKey).update(`${group}:${identity}`).digest();
    const row = (await pool.query(`INSERT INTO nomadfi.rate_windows (key_hash, window_at, count)
      VALUES ($1, date_trunc('minute', clock_timestamp()), 1) ON CONFLICT (key_hash) DO UPDATE
      SET window_at = EXCLUDED.window_at, count = CASE WHEN nomadfi.rate_windows.window_at = EXCLUDED.window_at
        THEN nomadfi.rate_windows.count + 1 ELSE 1 END RETURNING count`, [key])).rows[0];
    if (row.count > maximum) throw new ServiceError('RATE_LIMITED', 429);
  };
  const server = createServer({ maxHeaderSize: 8192, requestTimeout: 120000, headersTimeout: 10000 }, async (request, response) => {
    const requestID = randomUUID();
    response.setHeader('Content-Type', 'application/json'); response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff'); response.setHeader('X-Request-ID', requestID);
    const send = (status, value) => { response.writeHead(status); response.end(JSON.stringify(value)); };
    try {
      if (!request.url || request.url.length > 4096) throw new ServiceError('INVALID_REQUEST');
      const url = new URL(request.url, 'http://service.internal'), path = url.pathname, method = request.method;
      if (method === 'GET' && path === '/health') { send(200, { status: 'ok' }); return; }
      await rate(request.socket.remoteAddress ?? 'unknown', 'ingress', 300);
      if (method === 'POST' && path === '/webhooks/plaid') {
        await rate('plaid', 'webhooks', 120);
        send(200, await webhooks.receive(await body(request, 262144), request.headers['plaid-verification'])); return;
      }
      if (!['GET', 'POST', 'DELETE'].includes(method)) throw new ServiceError('METHOD_NOT_ALLOWED', 405);
      const mutating = method !== 'GET';
      if (mutating && request.headers['content-type']?.split(';')[0] !== 'application/json') throw new ServiceError('JSON_REQUIRED', 415);
      const input = mutating ? object(await body(request)) : {};
      if (method === 'POST' && path.startsWith('/auth/')) {
        await rate(request.socket.remoteAddress ?? 'unknown', 'authentication', 20);
        if (path === '/auth/challenge') { send(200, await auth.challenge()); return; }
        if (path === '/auth/apple') { send(200, await auth.login({ challengeID: input.challenge_id,
          identityToken: input.identity_token, authorizationCode: input.authorization_code })); return; }
        if (path === '/auth/refresh') { send(200, await auth.refresh(input.refresh_token)); return; }
      }
      const authorization = request.headers.authorization;
      if (typeof authorization !== 'string' || !/^Bearer [A-Za-z0-9_-]{32,256}$/.test(authorization)) throw new ServiceError('SESSION_INVALID', 401);
      const session = await auth.authenticate(authorization.slice(7)), userID = session.user_id;
      await rate(userID, 'authenticated', 120);
      if (method === 'POST' && path === '/auth/logout') { await auth.logout(session.id, userID); send(200, { status: 'signed_out' }); return; }
      if (method === 'DELETE' && path === '/account') { send(202, await revocation.deleteAccount(userID)); return; }
      if (method === 'GET' && path === '/connections') { send(200, { connections: await store.connections(userID) }); return; }
      if (method === 'POST' && path === '/link') {
        await rate(userID, 'link', 5); send(200, await link.begin(userID, input.connection_id ?? null)); return;
      }
      if (method === 'POST' && path === '/link/exchange') {
        await rate(userID, 'exchange', 10);
        send(200, await link.exchange(userID, input.attempt_id, input.public_token)); return;
      }
      const connection = /^\/connections\/([^/]+)(\/sync|\/updated)?$/.exec(path);
      if (connection) {
        const id = uuid(connection[1]);
        if (method === 'DELETE' && !connection[2]) { send(202, await revocation.disconnect(userID, id)); return; }
        if (method === 'POST' && connection[2] === '/updated') { send(200, await link.completeUpdate(userID, id)); return; }
        if (method === 'POST' && connection[2] === '/sync') {
          await rate(userID, 'manual-sync', 5); await store.requestSync(userID, id); send(202, { status: 'queued' }); return;
        }
      }
      if (method === 'POST' && path === '/snapshots') { send(201, await delivery.begin(userID)); return; }
      const snapshot = /^\/snapshots\/([^/]+)$/.exec(path);
      if (method === 'GET' && snapshot) {
        send(200, await delivery.page(userID, snapshot[1], url.searchParams.get('after') ?? '0')); return;
      }
      if (method === 'GET' && path === '/changes') {
        send(200, await store.changes(userID, { revision: url.searchParams.get('revision') ?? '0',
          offset: Number(url.searchParams.get('offset') ?? '-1'), through: url.searchParams.get('through') })); return;
      }
      if (method === 'POST' && path === '/acknowledgments') {
        await store.acknowledge(userID, uuid(input.device_id), input.checkpoint ?? {}); send(200, { status: 'acknowledged' }); return;
      }
      throw new ServiceError('NOT_FOUND', 404);
    } catch (error) {
      const status = error instanceof ServiceError ? error.status : error instanceof StoreError
        ? (error.code === 'NOT_FOUND' ? 404 : 409) : 500;
      const code = error instanceof ServiceError || error instanceof StoreError ? error.code : 'INTERNAL_ERROR';
      logger({ event: 'request_failed', request_id: requestID, status, code });
      if (!response.headersSent) send(status, { error: code, request_id: requestID });
      else response.end();
    }
  });
  server.setTimeout(120000, socket => socket.destroy());
  return server;
}
