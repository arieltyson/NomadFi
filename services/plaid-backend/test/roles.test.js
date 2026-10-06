import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { temporaryPostgres } from '../scripts/postgres-fixture.js';
import { migrate } from '../src/database.js';

test('runtime cannot change schema and FiBot cannot read identity or provider credentials', async () => {
  const database = await temporaryPostgres(), pool = database.pool;
  try {
    await migrate(pool);
    await pool.query(await readFile(new URL('../ops/roles.sql', import.meta.url), 'utf8'));
    const client = await pool.connect();
    try {
      await client.query('SET ROLE nomadfi_runtime');
      await client.query('SELECT count(*) FROM nomadfi.connections');
      await assert.rejects(client.query('ALTER TABLE nomadfi.users ADD COLUMN forbidden text'), { code: '42501' });
      await client.query('RESET ROLE'); await client.query('SET ROLE nomadfi_fibot');
      await client.query('SELECT count(*) FROM nomadfi.ledger_records');
      for (const table of ['credentials', 'sessions', 'apple_grants', 'link_attempts', 'users']) {
        await assert.rejects(client.query(`SELECT * FROM nomadfi.${table}`), { code: '42501' });
      }
      await client.query('RESET ROLE');
    } finally { client.release(); }
  } finally { await pool.end(); await database.stop(); }
});
