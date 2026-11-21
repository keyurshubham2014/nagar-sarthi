import pg from 'pg';
import { config } from './config.js';

export const pool = new pg.Pool({ connectionString: config.databaseUrl, max: 5 });
// An idle-client error must not crash the server; read endpoints work without Postgres.
pool.on('error', (e) => console.warn('[db] pool error:', e.message));

const TABLES = ['users', 'complaints', 'verification_reports'];

/** Returns {ok, tables} and never throws. */
export async function dbStatus() {
  try {
    const { rows } = await pool.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ANY($1)",
      [TABLES],
    );
    const found = rows.map((r) => r.table_name).sort();
    return { ok: found.length === TABLES.length, tables: found };
  } catch (e) {
    return { ok: false, tables: [], error: e.code ?? e.message };
  }
}
