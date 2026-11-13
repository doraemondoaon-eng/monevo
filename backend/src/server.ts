import { buildApp } from './app.js';
import { AppError } from './common/errors.js';
import { loadEnv } from './config/env.js';
import { createPgDatabase } from './db/client.js';
import { isTransientDbError, runMigrationsWithRetry } from './db/migrate.js';

async function main() {
  const env = loadEnv();
  const { db, close } = createPgDatabase({
    url: env.DATABASE_URL,
    ssl: env.DATABASE_SSL,
    max: env.DATABASE_POOL_MAX,
  });

  let migrationsCompleted = !env.RUN_MIGRATIONS_ON_START;
  let migrationInFlight: Promise<void> | null = null;

  const ensureMigrationsReady = async (): Promise<void> => {
    if (migrationsCompleted) {
      return;
    }
    if (!migrationInFlight) {
      migrationInFlight = (async () => {
        console.log('Running database migrations on startup...');
        await runMigrationsWithRetry(db, {
          onRetry: (attempt, delayMs, err) => {
            const msg = err instanceof Error ? err.message : String(err);
            console.warn(
              `Database connection transient error during migration (attempt ${attempt}), retrying in ${delayMs}ms: ${msg}`,
            );
          },
        });
        migrationsCompleted = true;
        console.log('Database migrations up to date.');
      })().finally(() => {
        migrationInFlight = null;
      });
    }

    try {
      await migrationInFlight;
    } catch (err) {
      if (isTransientDbError(err)) {
        throw AppError.serviceUnavailable(
          'Database is waking up or temporarily unreachable. Please try again in a few seconds.',
        );
      }
      throw err;
    }
  };

  // Start migration warm-up in the background so /health listens immediately and survives cold DB wake-ups.
  if (env.RUN_MIGRATIONS_ON_START) {
    void ensureMigrationsReady().catch((err) => {
      console.error('Background startup migration warning:', err);
    });
  }

  const app = await buildApp({
    env,
    db,
    beforeApiRequest: env.RUN_MIGRATIONS_ON_START ? ensureMigrationsReady : undefined,
  });

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

