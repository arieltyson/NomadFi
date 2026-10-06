import pg from 'pg';
import { FiBotMonitor } from './fibot-service.js';
import { swiftEvaluator } from './fibot-engine.js';

let pool;
try {
  const uri = new URL(process.env.FIBOT_DATABASE_URL);
  if (!['postgres:', 'postgresql:'].includes(uri.protocol) || uri.search || uri.hash) throw new Error();
  const local = process.env.RUNTIME_ENV === 'local';
  const socket = process.env.FIBOT_DATABASE_SOCKET;
  if (socket && (local || !/^\/cloudsql\/[a-z][a-z0-9-]+:[a-z0-9-]+:[a-z][a-z0-9-]+$/.test(socket))) throw new Error();
  if (local && !['localhost', '127.0.0.1', '[::1]'].includes(uri.hostname)) throw new Error();
  if (!local && process.env.HOSTED_DATA_ACCEPTANCE !== 'reviewed') throw new Error();
  pool = new pg.Pool({ connectionString: uri.toString(), ...(socket ? { host: socket } : {}),
    ssl: local || socket ? false : { rejectUnauthorized: true, ca: process.env.FIBOT_DATABASE_CA_PEM },
    max: 2, connectionTimeoutMillis: 10000 });
  pool.on('error', () => {});
  const access = (await pool.query(`SELECT has_table_privilege(current_user, 'nomadfi.credentials', 'SELECT') AS tokens,
    has_table_privilege(current_user, 'nomadfi.users', 'SELECT') AS identities,
    has_table_privilege(current_user, 'nomadfi.fibot_profiles', 'UPDATE') AS change_consent`)).rows[0];
  if (access.tokens || access.identities || access.change_consent) throw new Error();
  const worker = new FiBotMonitor({ pool, evaluate: swiftEvaluator(process.env.FIBOT_ENGINE_PATH) });
  for (let index = 0; index < 50; index++) { if ((await worker.runOne()).status === 'idle') break; }
} catch {
  console.error(JSON.stringify({ event: 'fibot_runtime_failed' })); process.exitCode = 1;
} finally { await pool?.end(); }
