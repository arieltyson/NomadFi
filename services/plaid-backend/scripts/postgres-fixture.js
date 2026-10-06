import EmbeddedPostgres from 'embedded-postgres';
import { randomBytes } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createServer } from 'node:net';
import pg from 'pg';

export async function temporaryPostgres() {
  process.umask(0o077);
  const listener = createServer();
  await new Promise((resolve, reject) => {
    listener.once('error', reject);
    listener.listen(0, '127.0.0.1', resolve);
  });
  const port = listener.address().port;
  await new Promise(resolve => listener.close(resolve));
  const directory = await mkdtemp(join(tmpdir(), 'nomadfi-postgres-test-'));
  const password = randomBytes(32).toString('hex');
  const config = { host: '127.0.0.1', port, user: 'postgres', password, database: 'postgres', max: 8 };
  const server = new EmbeddedPostgres({
    databaseDir: join(directory, 'data'), user: config.user, password, port,
    authMethod: 'scram-sha-256', persistent: true, createPostgresUser: false,
    postgresFlags: ['-h', '127.0.0.1'], onLog: () => {}, onError: () => {},
  });
  try {
    await server.initialise();
    await server.start();
    return {
      pool: new pg.Pool(config), config,
      async restart() { await server.stop(); await server.start(); },
      async stop() {
        await server.stop();
        await rm(directory, { recursive: true, force: true });
      },
    };
  } catch (error) {
    await server.stop().catch(() => {});
    await rm(directory, { recursive: true, force: true });
    throw error;
  }
}
