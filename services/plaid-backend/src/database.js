import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';

export async function transaction(pool, operation) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SET LOCAL statement_timeout = '15s'");
    await client.query("SET LOCAL idle_in_transaction_session_timeout = '15s'");
    const result = await operation(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function migrate(pool) {
  const directory = new URL('../migrations/', import.meta.url);
  const files = (await readdir(directory)).filter(name => /^\d+_.+\.sql$/.test(name)).sort();
  await transaction(pool, async client => {
    await client.query('SELECT pg_advisory_xact_lock(184201, 1)');
    await client.query(`CREATE TABLE IF NOT EXISTS public.nomadfi_migrations (
      name text PRIMARY KEY, digest text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now()
    )`);
    await client.query('REVOKE ALL ON public.nomadfi_migrations FROM PUBLIC');
    for (const name of files) {
      const sql = await readFile(new URL(name, directory), 'utf8');
      const digest = createHash('sha256').update(sql).digest('hex');
      const existing = await client.query('SELECT digest FROM public.nomadfi_migrations WHERE name = $1', [name]);
      if (existing.rowCount) {
        if (existing.rows[0].digest !== digest) throw new Error('MIGRATION_CHANGED');
        continue;
      }
      await client.query(sql);
      await client.query('INSERT INTO public.nomadfi_migrations (name, digest) VALUES ($1, $2)', [name, digest]);
    }
  });
}
