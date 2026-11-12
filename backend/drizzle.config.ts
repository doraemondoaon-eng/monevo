import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/db/schema.ts',
  out: './drizzle',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? 'postgres://monevo:monevo_dev_password@localhost:5432/monevo',
  },
  strict: true,
  verbose: true,
});
