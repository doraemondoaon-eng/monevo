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
