import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { booleanQuery, dataEnvelope, uuidParam } from '../../common/schemas.js';
import { accountDto, createAccountBody, updateAccountBody } from './accounts.schemas.js';
import type { AccountsService } from './accounts.service.js';

export function registerAccountRoutes(app: FastifyInstance, accounts: AccountsService): void {
  const r = app.withTypeProvider<ZodTypeProvider>();

  r.get(
    '/accounts',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Accounts'],
        summary: 'List all user accounts',
        querystring: z.object({ includeArchived: booleanQuery }),
        response: { 200: dataEnvelope(z.array(accountDto)) },
      },
    },
    async (req) => ({
      data: await accounts.list(req.userId, req.query.includeArchived ?? false),
    }),
  );

  r.post(
    '/accounts',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Accounts'],
        summary: 'Create a new account',
        body: createAccountBody,
        response: { 201: dataEnvelope(accountDto) },
      },
    },
    async (req, reply) => {
      const created = await accounts.create(req.userId, req.body);
      return reply.status(201).send({ data: created });
    },
  );

  r.get(
    '/accounts/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Accounts'],
        summary: 'Get an account by ID',
        params: uuidParam,
        response: { 200: dataEnvelope(accountDto) },
      },
    },
    async (req) => ({
      data: await accounts.get(req.userId, req.params.id),
    }),
  );

  r.patch(
    '/accounts/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Accounts'],
        summary: 'Update an account',
        params: uuidParam,
        body: updateAccountBody,
        response: { 200: dataEnvelope(accountDto) },
      },
    },
    async (req) => ({
      data: await accounts.update(req.userId, req.params.id, req.body),
    }),
  );

  r.delete(
    '/accounts/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Accounts'],
        summary: 'Delete an account (if it has no transactions)',
        params: uuidParam,
        response: { 204: z.null() },
      },
    },
    async (req, reply) => {
      await accounts.remove(req.userId, req.params.id);
      return reply.status(204).send(null);
    },
  );

  r.post(
    '/accounts/:id/reconcile',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Accounts'],
        summary: 'Recompute account balance from ledger transactions',
        params: uuidParam,
        response: { 200: dataEnvelope(accountDto) },
      },
    },
    async (req) => ({
      data: await accounts.reconcile(req.userId, req.params.id),
    }),
  );
}

