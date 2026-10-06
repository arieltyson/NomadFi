import EmbeddedPostgres from 'embedded-postgres';
import { randomBytes } from 'node:crypto';
import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

process.umask(0o077);
const directory = resolve('.local-postgres');
await mkdir(directory, { recursive: true, mode: 0o700 });
const credentialsPath = resolve(directory, 'credentials.json');
let credentials;
try {
  credentials = JSON.parse(await readFile(credentialsPath, 'utf8'));
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  credentials = { user: 'postgres', password: randomBytes(32).toString('hex'), port: 55432 };
  await writeFile(credentialsPath, JSON.stringify(credentials), { mode: 0o600, flag: 'wx' });
}
const server = new EmbeddedPostgres({
  databaseDir: resolve(directory, 'data'), ...credentials, authMethod: 'scram-sha-256',
  persistent: true, createPostgresUser: false, postgresFlags: ['-h', '127.0.0.1'],
  onLog: () => {}, onError: () => {},
});
try {
  await access(resolve(directory, 'data/PG_VERSION'));
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  await server.initialise();
}
await server.start();
await writeFile('.env.local', `DATABASE_URL=postgresql://${credentials.user}:${credentials.password}@127.0.0.1:${credentials.port}/postgres\n`, { mode: 0o600 });
console.log('Local PostgreSQL listening on 127.0.0.1:55432; credentials saved in ignored .env.local.');
await new Promise(resolve => {
  process.once('SIGINT', resolve);
  process.once('SIGTERM', resolve);
});
await server.stop();
