import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { loadEnv } from '../config/env.js';
import { createPgDatabase, type Database } from './client.js';

export const MIGRATIONS_FOLDER = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../drizzle');

export async function runMigrations(db: Database): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  await migrate(db as any, { migrationsFolder: MIGRATIONS_FOLDER });
}

const TRANSIENT_DB_ERROR_CODES = new Set([
  'ECONNRESET',
  'ECONNREFUSED',
  'ETIMEDOUT',
  'EPIPE',
  'EAI_AGAIN',
  'ENOTFOUND',
  '57P03', // cannot_connect_now (PostgreSQL starting up)
]);

export function isTransientDbError(err: unknown): boolean {
  let current: unknown = err;
  for (let depth = 0; depth < 4 && current != null; depth++) {
    if (typeof current === 'object') {
      const rec = current as { code?: unknown; message?: unknown; cause?: unknown };
      if (typeof rec.code === 'string' && TRANSIENT_DB_ERROR_CODES.has(rec.code)) {
        return true;
      }
      if (typeof rec.message === 'string') {
        const msg = rec.message.toLowerCase();
        if (
          msg.includes('socket disconnected before secure tls connection was established') ||
          msg.includes('connection terminated unexpectedly') ||
          msg.includes('timeout exceeded when trying to connect') ||
          msg.includes('econnreset') ||
          msg.includes('econnrefused')
        ) {
          return true;
        }
      }
      current = rec.cause;
    } else {
      break;
    }
  }
  return false;
}

export async function runMigrationsWithRetry(
  db: Database,
  options: {
    delaysMs?: number[];
    run?: (database: Database) => Promise<void>;
    onRetry?: (attempt: number, delayMs: number, err: unknown) => void;
  } = {},
): Promise<void> {
  const delays = options.delaysMs ?? [1500, 3000, 5000, 5000];
  const execute = options.run ?? runMigrations;

  for (let attempt = 1; ; attempt++) {
    try {
      await execute(db);
      return;
    } catch (err) {
      const retryIndex = attempt - 1;
      const delayMs = delays[retryIndex];
      if (delayMs === undefined || !isTransientDbError(err)) {
        throw err;
      }
      options.onRetry?.(attempt, delayMs, err);
      await new Promise<void>((resolve) => {
        setTimeout(resolve, delayMs);
      });
    }
  }
}

// CLI entry: `npm run db:migrate` (dev) / `npm run db:migrate:prod` (built)
const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const env = loadEnv();
  const { db, close } = createPgDatabase({ url: env.DATABASE_URL, ssl: env.DATABASE_SSL, max: 1 });
  runMigrations(db)
    .then(() => {
      console.log('โ” Migrations applied');
      return close();
    })
    .catch(async (err) => {
      console.error('โ– Migration failed', err);
      await close();
      process.exit(1);
    });
}
