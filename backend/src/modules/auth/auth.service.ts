import { AppError } from '../../common/errors.js';
import type { AppSettingsRow, UserRow } from '../../db/schema.js';
import { dummyHash, hashPassword, verifyPassword } from '../../security/password.js';
import type { TokenService } from '../../security/tokens.js';
import { DEFAULT_EXPENSE_CATEGORIES, DEFAULT_INCOME_CATEGORIES } from '../categories/defaults.js';
import type { AuthRepository } from './auth.repository.js';

export interface PublicUser {
  id: string;
  email: string;
  displayName: string;
  baseCurrency: string;
  timezone: string;
  createdAt: string;
}

export interface Tokens {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
  refreshTokenExpiresAt: string;
}

export function toPublicUser(u: UserRow): PublicUser {
  return {
    id: u.id,
    email: u.email,
    displayName: u.displayName,
    baseCurrency: u.baseCurrency,
    timezone: u.timezone,
    createdAt: u.createdAt.toISOString(),
  };
}

export function toAppSettingsDto(s: AppSettingsRow) {
  return {
    themeMode: s.themeMode as 'system' | 'light' | 'dark',
    language: s.language as 'th' | 'en',
    useBuddhistEra: s.useBuddhistEra,
    privacyMode: s.privacyMode,
    autoLockSeconds: s.autoLockSeconds,
    updatedAt: s.updatedAt.toISOString(),
  };
}

export function isValidTimezone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

export class AuthService {
  constructor(
    private readonly repo: AuthRepository,
    private readonly tokens: TokenService,
  ) {}

  /** Single-owner mode: registration is open only until the first user exists. */
  async isRegistrationOpen(): Promise<boolean> {
    return !(await this.repo.hasAnyUser());
  }

  async register(input: { email: string; password: string; displayName: string }, userAgent?: string) {
    const passwordHash = await hashPassword(input.password);
    const seeds = [
      ...DEFAULT_EXPENSE_CATEGORIES.map((c, i) => ({ ...c, type: 'expense' as const, sortOrder: i })),
      ...DEFAULT_INCOME_CATEGORIES.map((c, i) => ({ ...c, type: 'income' as const, sortOrder: i })),
    ];

    const created = await this.repo.createOwnerWithSeedCategories(
      {
        email: input.email.toLowerCase(),
        passwordHash,
        displayName: input.displayName,
      },
      seeds,
    );
    if (!created) {
      throw AppError.forbidden('REGISTRATION_CLOSED', 'Registration is closed');
    }

    const tokens = await this.issueTokens(created.id, crypto.randomUUID(), userAgent);
    return { user: toPublicUser(created), tokens };
  }

  async login(input: { email: string; password: string }, userAgent?: string) {
    const user = await this.repo.findUserByEmail(input.email);

    if (!user) {
      await verifyPassword(await dummyHash(), input.password); // constant-ish timing
      throw AppError.unauthorized('INVALID_CREDENTIALS', 'Invalid email or password');
    }
    const ok = await verifyPassword(user.passwordHash, input.password);
    if (!ok) throw AppError.unauthorized('INVALID_CREDENTIALS', 'Invalid email or password');

    const tokens = await this.issueTokens(user.id, crypto.randomUUID(), userAgent);
    return { user: toPublicUser(user), tokens };
  }

  /** Rotates the refresh token. Presenting an already-rotated token revokes the whole family. */
  async refresh(rawToken: string, userAgent?: string): Promise<Tokens> {
    const tokenHash = this.tokens.hashRefreshToken(rawToken);
    const stored = await this.repo.findRefreshTokenByHash(tokenHash);

    if (!stored) throw AppError.unauthorized('INVALID_TOKEN', 'Invalid refresh token');

    if (stored.revokedAt) {
      // Reuse of a rotated/revoked token → likely theft. Kill the entire session family.
      await this.repo.revokeFamily(stored.familyId);
      throw AppError.unauthorized('INVALID_TOKEN', 'Refresh token has been revoked');
    }
    if (stored.expiresAt.getTime() <= Date.now()) {
      throw AppError.unauthorized('TOKEN_EXPIRED', 'Refresh token expired');
    }

    const next = this.tokens.generateRefreshToken();
    try {
      await this.repo.rotateRefreshToken(stored.id, {
        userId: stored.userId,
        tokenHash: next.hash,
        familyId: stored.familyId,
        expiresAt: next.expiresAt,
        userAgent: userAgent?.slice(0, 255),
      });
    } catch {
      throw AppError.unauthorized('INVALID_TOKEN', 'Refresh token has been revoked');
    }

    return {
      accessToken: await this.tokens.signAccessToken(stored.userId),
      refreshToken: next.token,
      accessTokenExpiresIn: this.tokens.accessTtlSeconds,
      refreshTokenExpiresAt: next.expiresAt.toISOString(),
    };
  }

  async logout(rawToken: string): Promise<void> {
    const tokenHash = this.tokens.hashRefreshToken(rawToken);
    await this.repo.revokeRefreshTokenByHash(tokenHash);
  }

  async getUser(userId: string): Promise<PublicUser> {
    const user = await this.repo.findUserById(userId);
    if (!user) throw AppError.unauthorized('INVALID_TOKEN', 'User no longer exists');
    return toPublicUser(user);
  }

  async updateProfile(userId: string, input: { displayName?: string; timezone?: string }): Promise<PublicUser> {
    if (input.timezone !== undefined && !isValidTimezone(input.timezone)) {
      throw AppError.validation('Invalid timezone', [{ path: 'timezone', message: 'Unknown IANA timezone' }]);
    }
    const user = await this.repo.updateUser(userId, input);
    if (!user) throw AppError.notFound('User');
    return toPublicUser(user);
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string): Promise<void> {
    const user = await this.repo.findUserById(userId);
    if (!user) throw AppError.notFound('User');
    if (!(await verifyPassword(user.passwordHash, currentPassword))) {
      throw AppError.unauthorized('INVALID_CREDENTIALS', 'Current password is incorrect');
    }
    const passwordHash = await hashPassword(newPassword);
    await this.repo.updatePasswordAndRevokeSessions(userId, passwordHash);
  }

  async getSettings(userId: string) {
    const s = await this.repo.getOrCreateAppSettings(userId);
    return toAppSettingsDto(s);
  }

  async updateSettings(
    userId: string,
    patch: {
      themeMode?: 'system' | 'light' | 'dark';
      language?: 'th' | 'en';
      useBuddhistEra?: boolean;
      privacyMode?: boolean;
      autoLockSeconds?: number;
    },
  ) {
    const s = await this.repo.updateAppSettings(userId, patch);
    return toAppSettingsDto(s);
  }

  private async issueTokens(userId: string, familyId: string, userAgent?: string): Promise<Tokens> {
    const refresh = this.tokens.generateRefreshToken();
    await this.repo.insertRefreshToken({
      userId,
      tokenHash: refresh.hash,
      familyId,
      expiresAt: refresh.expiresAt,
      userAgent: userAgent?.slice(0, 255),
    });
    return {
      accessToken: await this.tokens.signAccessToken(userId),
      refreshToken: refresh.token,
      accessTokenExpiresIn: this.tokens.accessTtlSeconds,
      refreshTokenExpiresAt: refresh.expiresAt.toISOString(),
    };
  }
}
