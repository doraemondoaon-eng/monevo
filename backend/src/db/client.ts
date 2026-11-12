import { drizzle } from 'drizzle-orm/node-postgres';
import type { PgDatabase, PgQueryResultHKT } from 'drizzle-orm/pg-core';
import pg from 'pg';
import * as schema from './schema.js';

/**
 * Driver-agnostic database handle. Production uses node-postgres; tests use PGlite.
 * A transaction handle is also assignable to this type, so repositories accept either.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Database = PgDatabase<PgQueryResultHKT, typeof schema, any>;

export interface DbHandle {
  db: Database;
  close: () => Promise<void>;
}

export function createPgDatabase(options: { url: string; ssl: boolean; max: number }): DbHandle {
  const pool = new pg.Pool({
    connectionString: options.url,
    max: options.max,
    ssl: options.ssl ? { rejectUnauthorized: true } : undefined,
    // Neon scales to zero; allow time for a cold compute to wake up.
    connectionTimeoutMillis: 15_000,
    idleTimeoutMillis: 30_000,
  });
  const db = drizzle(pool, { schema }) as unknown as Database;
  return { db, close: () => pool.end() };
}

/** Extracts rows from a raw `db.execute()` result regardless of driver. */
export function rowsOf<T>(result: unknown): T[] {
  if (Array.isArray(result)) return result as T[];
  return ((result as { rows?: T[] }).rows ?? []) as T[];
}
