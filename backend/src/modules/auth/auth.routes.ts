import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { dataEnvelope } from '../../common/schemas.js';
import {
  appSettingsDto,
  authResultDto,
  authStatusDto,
  changePasswordBody,
  loginBody,
  refreshBody,
  registerBody,
  tokensDto,
  updateAppSettingsBody,
  updateProfileBody,
  userDto,
} from './auth.schemas.js';
import type { AuthService } from './auth.service.js';

export function registerAuthRoutes(app: FastifyInstance, auth: AuthService): void {
  const r = app.withTypeProvider<ZodTypeProvider>();

  r.get(
    '/auth/status',
    {
      schema: {
        tags: ['Auth'],
        summary: 'Check whether initial owner registration is open',
        response: { 200: dataEnvelope(authStatusDto) },
      },
    },
    async () => ({
      data: { registrationOpen: await auth.isRegistrationOpen() },
    }),
  );

  r.post(
    '/auth/register',
    {
      config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
      schema: {
        tags: ['Auth'],
        summary: 'Register the owner account (only allowed once)',
        body: registerBody,
        response: { 201: dataEnvelope(authResultDto) },
      },
    },
    async (req, reply) => {
      const result = await auth.register(req.body, req.headers['user-agent']);
      return reply.status(201).send({ data: result });
    },
  );

  r.post(
    '/auth/login',
    {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
      schema: {
        tags: ['Auth'],
        summary: 'Sign in with email & password',
        body: loginBody,
        response: { 200: dataEnvelope(authResultDto) },
      },
    },
    async (req) => ({
      data: await auth.login(req.body, req.headers['user-agent']),
    }),
  );

  r.post(
    '/auth/refresh',
    {
      config: { rateLimit: { max: 20, timeWindow: '1 minute' } },
      schema: {
        tags: ['Auth'],
        summary: 'Rotate refresh token and issue a new access token',
        body: refreshBody,
        response: { 200: dataEnvelope(z.object({ tokens: tokensDto })) },
      },
    },
    async (req) => ({
      data: { tokens: await auth.refresh(req.body.refreshToken, req.headers['user-agent']) },
    }),
  );

  r.post(
    '/auth/logout',
    {
      schema: {
        tags: ['Auth'],
        summary: 'Revoke a refresh token',
        body: refreshBody,
        response: { 204: z.null() },
      },
    },
    async (req, reply) => {
      await auth.logout(req.body.refreshToken);
      return reply.status(204).send(null);
    },
  );

  r.get(
    '/auth/me',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Auth'],
        summary: 'Get current user profile',
        response: { 200: dataEnvelope(userDto) },
      },
    },
    async (req) => ({
      data: await auth.getUser(req.userId),
    }),
  );

  r.patch(
    '/auth/me',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Auth'],
        summary: 'Update current user profile',
        body: updateProfileBody,
        response: { 200: dataEnvelope(userDto) },
      },
    },
    async (req) => ({
      data: await auth.updateProfile(req.userId, req.body),
    }),
  );

  r.post(
    '/auth/change-password',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Auth'],
        summary: 'Change password and revoke all active refresh tokens',
        body: changePasswordBody,
        response: { 204: z.null() },
      },
    },
    async (req, reply) => {
      await auth.changePassword(req.userId, req.body.currentPassword, req.body.newPassword);
      return reply.status(204).send(null);
    },
  );

  r.get(
    '/auth/settings',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Auth'],
        summary: 'Get user application settings from app_settings table',
        response: { 200: dataEnvelope(appSettingsDto) },
      },
    },
    async (req) => ({
      data: await auth.getSettings(req.userId),
    }),
  );

  r.patch(
    '/auth/settings',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Auth'],
        summary: 'Update user application settings in app_settings table',
        body: updateAppSettingsBody,
        response: { 200: dataEnvelope(appSettingsDto) },
      },
    },
    async (req) => ({
      data: await auth.updateSettings(req.userId, req.body),
    }),
  );
}

