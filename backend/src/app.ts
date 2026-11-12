import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import Fastify, { type FastifyInstance } from 'fastify';
import {
  jsonSchemaTransform,
  serializerCompiler,
  validatorCompiler,
  type ZodTypeProvider,
} from 'fastify-type-provider-zod';
import { z } from 'zod';
import type { Env } from './config/env.js';
import type { Database } from './db/client.js';
import { authPlugin } from './middleware/auth.js';
import { registerErrorHandler } from './middleware/error-handler.js';
import { registerStoragePolicyEnforcement } from './middleware/storage-policy.js';
import { AccountsRepository } from './modules/accounts/accounts.repository.js';
import { registerAccountRoutes } from './modules/accounts/accounts.routes.js';
import { AccountsService } from './modules/accounts/accounts.service.js';
import { AuthRepository } from './modules/auth/auth.repository.js';
import { registerAuthRoutes } from './modules/auth/auth.routes.js';
import { AuthService } from './modules/auth/auth.service.js';
import { CategoriesRepository } from './modules/categories/categories.repository.js';
import { registerCategoryRoutes } from './modules/categories/categories.routes.js';
import { CategoriesService } from './modules/categories/categories.service.js';
import { DashboardRepository } from './modules/dashboard/dashboard.repository.js';
import { registerDashboardRoutes } from './modules/dashboard/dashboard.routes.js';
import { DashboardService } from './modules/dashboard/dashboard.service.js';
import { TransactionsRepository } from './modules/transactions/transactions.repository.js';
import { registerTransactionRoutes } from './modules/transactions/transactions.routes.js';
import { TransactionsService } from './modules/transactions/transactions.service.js';
import { TokenService } from './security/tokens.js';

export interface BuildAppOptions {
  env: Env;
  db: Database;
}

const healthSchema = z.object({
  status: z.literal('ok'),
  uptime: z.number(),
  version: z.string(),
});

export async function buildApp({ env, db }: BuildAppOptions): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: env.LOG_LEVEL,
      redact: {
        paths: ['req.headers.authorization', 'body.password', 'body.currentPassword', 'body.newPassword', 'body.refreshToken'],
        censor: '[REDACTED]',
      },
    },
    trustProxy: true,
    // Section 3.1/3.2: Compact JSON-only payloads (32 KB max) to prevent image/blob uploads
    bodyLimit: 32 * 1024,
  });

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);
  registerErrorHandler(app);
  registerStoragePolicyEnforcement(app);

  await app.register(helmet, {
    contentSecurityPolicy: env.ENABLE_API_DOCS ? false : undefined,
  });

  const origins = env.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean);
  await app.register(cors, {
    origin: origins.includes('*') ? true : origins,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  await app.register(rateLimit, {
    global: true,
    max: 300,
    timeWindow: '1 minute',
  });

  if (env.ENABLE_API_DOCS) {
    await app.register(swagger, {
      openapi: {
        info: {
          title: 'MONEVO Personal Finance API',
          description: 'REST API for MONEVO personal finance application',
          version: '1.0.0',
        },
        components: {
          securitySchemes: {
            bearerAuth: {
              type: 'http',
              scheme: 'bearer',
              bearerFormat: 'JWT',
            },
          },
        },
      },
      transform: jsonSchemaTransform,
    });
    await app.register(swaggerUi, {
      routePrefix: '/docs',
    });
  }

  const tokens = new TokenService({
    accessSecret: env.JWT_ACCESS_SECRET,
    refreshSecret: env.JWT_REFRESH_SECRET,
    accessTtlSeconds: env.ACCESS_TOKEN_TTL_SECONDS,
    refreshTtlDays: env.REFRESH_TOKEN_TTL_DAYS,
  });

  await app.register(authPlugin, { tokens });

  // 1. Data Access Layer (Repositories — PostgreSQL / Drizzle ORM)
  const authRepository = new AuthRepository(db);
  const accountsRepository = new AccountsRepository(db);
  const categoriesRepository = new CategoriesRepository(db);
  const transactionsRepository = new TransactionsRepository(db);
  const dashboardRepository = new DashboardRepository(db);

  // 2. Business Logic Layer (Services — Pure Domain & Financial Rules)
  const authService = new AuthService(authRepository, tokens);
  const accountsService = new AccountsService(accountsRepository);
  const categoriesService = new CategoriesService(categoriesRepository);
  const transactionsService = new TransactionsService(
    transactionsRepository,
    accountsService,
    categoriesService,
  );
  const dashboardService = new DashboardService(dashboardRepository);

  const healthHandler = async () => ({
    status: 'ok' as const,
    uptime: process.uptime(),
    version: '1.0.0',
  });

  // Top-level health check (does NOT touch PostgreSQL so Neon can scale to zero when idle)
  app.withTypeProvider<ZodTypeProvider>().get(
    '/health',
    {
      config: { rateLimit: false },
      schema: {
        tags: ['Health'],
        summary: 'Liveness & wake-up probe (no database query)',
        response: { 200: healthSchema },
      },
    },
    healthHandler,
  );

  // 3. Transport / Presentation Layer (HTTP REST Routes + Zod Validation)
  await app.register(
    async (v1) => {
      v1.withTypeProvider<ZodTypeProvider>().get(
        '/health',
        {
          config: { rateLimit: false },
          schema: {
            tags: ['Health'],
            summary: 'Liveness & wake-up probe (alias under /api/v1)',
            response: { 200: healthSchema },
          },
        },
        healthHandler,
      );
      registerAuthRoutes(v1, authService);
      registerAccountRoutes(v1, accountsService);
      registerCategoryRoutes(v1, categoriesService);
      registerTransactionRoutes(v1, transactionsService);
      registerDashboardRoutes(v1, dashboardService);
    },
    { prefix: '/api/v1' },
  );

  return app;
}
