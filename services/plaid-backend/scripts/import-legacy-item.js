import pg from 'pg';
import { configuration } from '../src/configuration.js';
import { LocalTokenCipher, KMSTokenCipher } from '../src/token-cipher.js';
import { PlaidClient } from '../src/plaid-client.js';
import { SyncStore } from '../src/sync-store.js';
import { LegacyItemMigration } from '../src/legacy-item-migration.js';

let pool, cipher;
try {
  if (process.stdin.isTTY) throw new Error();
  const chunks = []; let size = 0;
  for await (const chunk of process.stdin) {
    size += chunk.length; if (size > 65536) throw new Error(); chunks.push(chunk);
  }
  const input = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  const config = configuration(process.env);
  pool = new pg.Pool(config.pool);
  cipher = config.encryptionMode === 'kms' ? new KMSTokenCipher(config.encryptionKey) : new LocalTokenCipher(config.encryptionKey);
  const migration = new LegacyItemMigration({ pool, store: new SyncStore(pool), plaid: new PlaidClient(config.plaid), cipher,
    webhookURL: config.webhookURL, allowedSubjects: config.allowedSubjects });
  console.log(JSON.stringify(await migration.run(input)));
} catch {
  console.error('Legacy Item migration could not be confirmed. No credentials or provider responses are logged.');
  process.exitCode = 1;
} finally { await pool?.end(); await cipher?.client?.close(); }
