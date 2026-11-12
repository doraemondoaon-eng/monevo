import { buildApp } from './app.js';
import { loadEnv } from './config/env.js';
import { createPgDatabase } from './db/client.js';
import { runMigrations } from './db/migrate.js';

async function main() {
  const env = loadEnv();
  const { db, close } = createPgDatabase({
    url: env.DATABASE_URL,
    ssl: env.DATABASE_SSL,
    max: env.DATABASE_POOL_MAX,
  });

  if (env.RUN_MIGRATIONS_ON_START) {
    console.log('Running database migrations on startup...');
    await runMigrations(db);
    console.log('Database migrations up to date.');
  }

  const app = await buildApp({ env, db });

  const shutdown = async (signal: string) => {
    app.log.info({ signal }, 'Shutting down gracefully...');
    try {
      await app.close();
      await close();
      process.exit(0);
    } catch (err) {
      app.log.error({ err }, 'Error during shutdown');
      process.exit(1);
    }
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));

  await app.listen({ port: env.PORT, host: env.HOST });
}

main().catch((err) => {
  console.error('Fatal startup error:', err);
  process.exit(1);
});

