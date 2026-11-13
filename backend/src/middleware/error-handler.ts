import type { FastifyError, FastifyInstance } from 'fastify';
import { hasZodFastifySchemaValidationErrors, isResponseSerializationError } from 'fastify-type-provider-zod';
import { AppError } from '../common/errors.js';

export function registerErrorHandler(app: FastifyInstance): void {
  app.setNotFoundHandler((_req, reply) => {
    reply.status(404).send({
      error: {
        code: 'NOT_FOUND',
        message: 'Route not found',
      },
    });
  });

  app.setErrorHandler((err: FastifyError | AppError | Error, req, reply) => {
    if (err instanceof AppError) {
      return reply.status(err.statusCode).send({
        error: {
          code: err.code,
          message: err.message,
          ...(err.details ? { details: err.details } : {}),
        },
      });
    }

    if (hasZodFastifySchemaValidationErrors(err)) {
      const details = err.validation.map((v) => ({
        path: String(v.instancePath ?? '').replace(/^\//, '').replace(/\//g, '.'),
        message: v.message ?? 'Invalid value',
      }));
      return reply.status(400).send({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Request validation failed',
          details,
        },
      });
    }

    const fastifyErr = err as FastifyError;
    if (fastifyErr.statusCode && fastifyErr.statusCode >= 400 && fastifyErr.statusCode < 500) {
      return reply.status(fastifyErr.statusCode).send({
        error: {
          code: fastifyErr.code || (fastifyErr.statusCode === 429 ? 'RATE_LIMITED' : 'BAD_REQUEST'),
          message: fastifyErr.message,
        },
      });
    }

    if (isResponseSerializationError(err)) {
      req.log.error({ err }, 'Response serialization failed');
      return reply.status(500).send({
        error: {
          code: 'SERIALIZATION_ERROR',
          message: err.message || 'Response serialization failed',
        },
      });
    }

    const errMessage = (err as Error)?.message || 'Internal server error';
    req.log.error({ err }, 'Unhandled error');
    return reply.status(500).send({
      error: {
        code: 'INTERNAL_ERROR',
        message: errMessage,
      },
    });
  });
}

