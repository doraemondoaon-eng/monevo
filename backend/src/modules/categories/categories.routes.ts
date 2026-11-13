import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { booleanQuery, dataEnvelope, uuidParam } from '../../common/schemas.js';
import { categoryDto, categoryType, createCategoryBody, updateCategoryBody } from './categories.schemas.js';
import type { CategoriesService } from './categories.service.js';

export function registerCategoryRoutes(app: FastifyInstance, categories: CategoriesService): void {
  const r = app.withTypeProvider<ZodTypeProvider>();

  r.get(
    '/categories',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Categories'],
        summary: 'List user categories',
        querystring: z.object({
          type: categoryType.optional(),
          includeArchived: booleanQuery,
        }),
        response: { 200: dataEnvelope(z.array(categoryDto)) },
      },
    },
    async (req) => ({
      data: await categories.list(req.userId, {
        type: req.query.type,
        includeArchived: req.query.includeArchived ?? false,
      }),
    }),
  );

  r.post(
    '/categories',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Categories'],
        summary: 'Create a category',
        body: createCategoryBody,
        response: { 201: dataEnvelope(categoryDto) },
      },
    },
    async (req, reply) => {
      const created = await categories.create(req.userId, req.body);
      return reply.status(201).send({ data: created });
    },
  );

  r.patch(
    '/categories/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Categories'],
        summary: 'Update a category',
        params: uuidParam,
        body: updateCategoryBody,
        response: { 200: dataEnvelope(categoryDto) },
      },
    },
    async (req) => ({
      data: await categories.update(req.userId, req.params.id, req.body),
    }),
  );

  r.delete(
    '/categories/:id',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Categories'],
        summary: 'Delete a category (if not used by any transaction)',
        params: uuidParam,
        response: { 204: z.void().or(z.null()).optional() },
      },
    },
    async (req, reply) => {
      await categories.remove(req.userId, req.params.id);
      return reply.status(204).send();
    },
  );
}

