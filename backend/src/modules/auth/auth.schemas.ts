import { z } from 'zod';

export const userDto = z.object({
  id: z.string(),
  email: z.string().email(),
  displayName: z.string(),
  baseCurrency: z.string(),
  timezone: z.string(),
  createdAt: z.string(),
});

export const tokensDto = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  accessTokenExpiresIn: z.number().int(),
  refreshTokenExpiresAt: z.string(),
});

export const authStatusDto = z.object({
  registrationOpen: z.boolean(),
});

export const authResultDto = z.object({
  user: userDto,
  tokens: tokensDto,
});

export const registerBody = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(10, 'Password must be at least 10 characters').max(128),
  displayName: z.string().trim().min(1).max(80),
});

export const loginBody = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(128),
});

export const refreshBody = z.object({
  refreshToken: z.string().min(1),
});

export const updateProfileBody = z.object({
  displayName: z.string().trim().min(1).max(80).optional(),
  timezone: z.string().trim().min(1).max(64).optional(),
});

export const changePasswordBody = z.object({
  currentPassword: z.string().min(1).max(128),
  newPassword: z.string().min(10, 'New password must be at least 10 characters').max(128),
});

export const appSettingsDto = z.object({
  themeMode: z.enum(['system', 'light', 'dark']),
  language: z.enum(['th', 'en']),
  useBuddhistEra: z.boolean(),
  privacyMode: z.boolean(),
  autoLockSeconds: z.number().int(),
  updatedAt: z.string(),
});

export const updateAppSettingsBody = z.object({
  themeMode: z.enum(['system', 'light', 'dark']).optional(),
  language: z.enum(['th', 'en']).optional(),
  useBuddhistEra: z.boolean().optional(),
  privacyMode: z.boolean().optional(),
  autoLockSeconds: z.number().int().min(0).max(3600).optional(),
});

