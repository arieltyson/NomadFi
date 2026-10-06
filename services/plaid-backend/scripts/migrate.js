import pg from 'pg';
import { migrate } from '../src/database.js';

if (!process.env.DATABASE_URL) {
  console.error('DATABASE_URL is required. Start npm run db:local for local development.');
  process.exit(1);
}
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
try {
  await migrate(pool);
  console.log('Database migrations applied.');
} catch {
  console.error('Migration failed. Inspect database configuration and migration integrity.');
  process.exitCode = 1;
} finally {
  await pool.end();
}
