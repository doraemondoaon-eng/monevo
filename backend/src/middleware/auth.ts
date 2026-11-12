import type { FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';
import { AppError } from '../common/errors.js';
import type { TokenService } from '../security/tokens.js';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
  interface FastifyInstance {
    authenticate: (request: FastifyRequest) => Promise<void>;
  }
}

export const authPlugin = fp(async (app, opts: { tokens: TokenService }) => {
  app.decorateRequest('userId', '');
  app.decorate('authenticate', async (request: FastifyRequest) => {
    const header = request.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      throw AppError.unauthorized('UNAUTHORIZED', 'Missing Bearer token');
    }
    const raw = header.slice('Bearer '.length).trim();
    if (!raw) {
      throw AppError.unauthorized('UNAUTHORIZED', 'Empty Bearer token');
    }
    request.userId = await opts.tokens.verifyAccessToken(raw);
  });
});

