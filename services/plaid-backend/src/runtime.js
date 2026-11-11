import pg from 'pg';
import { configuration } from './configuration.js';
import { AppleIdentity } from './apple-identity.js';
import { AuthService } from './auth-service.js';
import { LocalTokenCipher, KMSTokenCipher } from './token-cipher.js';
import { PlaidClient } from './plaid-client.js';
import { SyncStore } from './sync-store.js';
import { SyncWorker } from './sync-worker.js';
import { LinkService } from './link-service.js';
import { DeliveryService } from './delivery-service.js';
import { RevocationService } from './revocation-service.js';
import { WebhookService, enqueueStaleConnections } from './webhook-service.js';
import { createAPI } from './http-server.js';
import { AppleNotifications } from './apple-notifications.js';
import { FiBotService } from './fibot-service.js';
import { WorkerTrigger } from './worker-trigger.js';

const log = value => console.log(JSON.stringify(value));
let pool, server, cipher, stopping = false;
try {
  const config = configuration(process.env);
  pool = new pg.Pool(config.pool);
  pool.on('error', () => log({ event: 'database_connection_failed' }));
  cipher = config.encryptionMode === 'kms' ? new KMSTokenCipher(config.encryptionKey) : new LocalTokenCipher(config.encryptionKey);
  const apple = new AppleIdentity(config.apple), plaid = new PlaidClient(config.plaid), store = new SyncStore(pool);
  const auth = new AuthService({ pool, apple, cipher, allowedSubjects: config.allowedSubjects });
  const link = new LinkService({ pool, plaid, cipher, redirectURI: config.redirectURI, webhookURL: config.webhookURL });
  const revocation = new RevocationService({ pool, plaid, apple, cipher });
  const mode = process.argv[2] ?? 'api';
  process.on('SIGTERM', () => { stopping = true; if (server) server.close(); });
  process.on('SIGINT', () => { stopping = true; if (server) server.close(); });
  if (mode === 'api') {
    server = createAPI({ pool, auth, store, link, delivery: new DeliveryService(pool), revocation, fibot: new FiBotService(pool),
      appleNotifications: new AppleNotifications({ pool, apple, revocation }),
      webhooks: new WebhookService({ pool, plaid }), rateKey: config.rateKey, logger: log,
      workerTrigger: new WorkerTrigger({ jobName: config.workerJobName, logger: log }) });
    await new Promise((resolve, reject) => { server.once('error', reject); server.listen(config.port, config.host, resolve); });
    log({ event: 'api_listening' });
    await new Promise(resolve => server.once('close', resolve));
  } else if (mode === 'worker') {
    const worker = new SyncWorker({ store, plaid, cipher });
    for (let count = 0; count < 50 && !stopping; count++) {
      const revoked = await revocation.runOne(), sync = await worker.runOne();
      log({ event: 'worker_pass', revocation: revoked.status, sync: sync.status });
      if (revoked.status === 'idle' && sync.status === 'idle') break;
    }
  } else if (mode === 'sweep') {
    await pool.query(`UPDATE nomadfi.fibot_jobs SET requested_revision = requested_revision + 1,
      available_at = clock_timestamp() WHERE requested_revision = completed_revision
        AND available_at < clock_timestamp() - interval '1 day'`);
    await pool.query("DELETE FROM nomadfi.fibot_alerts WHERE created_at < clock_timestamp() - interval '30 days'");
    log({ event: 'stale_sweep', enqueued: await enqueueStaleConnections(pool) });
    await pool.query('DELETE FROM nomadfi.snapshots WHERE expires_at < clock_timestamp()');
    await pool.query("DELETE FROM nomadfi.auth_challenges WHERE expires_at < clock_timestamp() - interval '1 day'");
    await pool.query("DELETE FROM nomadfi.webhook_receipts WHERE received_at < clock_timestamp() - interval '1 day'");
    await pool.query("DELETE FROM nomadfi.rate_windows WHERE window_at < clock_timestamp() - interval '1 day'");
    await pool.query('DELETE FROM nomadfi.sessions WHERE absolute_expires_at < clock_timestamp()');
    await pool.query(`DELETE FROM nomadfi.sync_generations g USING nomadfi.sync_jobs j
      WHERE j.connection_id = g.connection_id AND g.published_at IS NULL AND g.lease_epoch < j.lease_epoch
        AND g.created_at < clock_timestamp() - interval '1 day'`);
  } else throw new Error('Invalid runtime mode');
} catch {
  log({ event: 'runtime_failed' }); process.exitCode = 1;
} finally {
  if (server?.listening) await new Promise(resolve => server.close(resolve));
  await pool?.end(); await cipher?.client?.close();
}
