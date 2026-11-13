import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { dataEnvelope, uuidParam } from '../../common/schemas.js';
import {
  createTransactionBody,
  listTransactionsQuery,
  transactionDto,
  transactionTypeInfoDto,
  updateTransactionBody,
} from './transactions.schemas.js';
import type { TransactionsService } from './transactions.service.js';

export function registerTransactionRoutes(app: FastifyInstance, transactions: TransactionsService): void {
  const r = app.withTypeProvider<ZodTypeProvider>();

  r.get(
    '/transactions/types',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Transactions'],
        summary: 'List canonical transaction types from transaction_types table',
        response: {
          200: dataEnvelope(z.array(transactionTypeInfoDto)),
        },
      },
    },
    async () => ({
      data: await transactions.listTypes(),
    }),
  );

  r.get(
    '/transactions',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Transactions'],
        summary: 'List transactions with filters and cursor pagination',
        querystring: listTransactionsQuery,
        response: {
          200: z.object({
            data: z.array(transactionDto),
            nextCursor: z.string().nullable(),
          }),
        },
      },
    },
    async (req) => transactions.list(req.userId, req.query),
  );

  r.post(
    '/transactions',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Transactions'],
        summary: 'Record an income, expense, or transfer transaction',
        body: createTransactionBody,
        response: { 201: dataEnvelope(transactionDto) },
      },
    },
    async (req, reply) => {
      const created = await transactions.create(req.userId, req.body);
      return reply.status(201).send({ data: created });
    },
  );

  r.get(
    '/transactions/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Transactions'],
        summary: 'Get a single transaction by ID',
        params: uuidParam,
        response: { 200: dataEnvelope(transactionDto) },
      },
    },
    async (req) => ({
      data: await transactions.get(req.userId, req.params.id),
    }),
  );

  r.patch(
    '/transactions/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Transactions'],
        summary: 'Update a transaction and adjust account balances atomically',
        params: uuidParam,
        body: updateTransactionBody,
        response: { 200: dataEnvelope(transactionDto) },
      },
    },
    async (req) => ({
      data: await transactions.update(req.userId, req.params.id, req.body),
    }),
  );

  r.delete(
    '/transactions/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Transactions'],
        summary: 'Soft-delete a transaction and reverse its balance impact',
        params: uuidParam,
        response: { 204: z.void().or(z.null()).optional() },
      },
    },
    async (req, reply) => {
      await transactions.remove(req.userId, req.params.id);
      return reply.status(204).send();
    },
  );
}

