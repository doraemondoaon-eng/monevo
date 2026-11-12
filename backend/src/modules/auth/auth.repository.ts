import { and, eq, isNull, lt, or, sql } from 'drizzle-orm';
import type { Database } from '../../db/client.js';
import {
  appSettings,
  categories,
  refreshTokens,
  users,
  type AppSettingsRow,
  type UserRow,
} from '../../db/schema.js';
import type { ICON_KEYS } from '../../common/schemas.js';

const REGISTRATION_LOCK_KEY = 727_274_001;

export interface SeedCategoryRecord {
  name: string;
  type: 'income' | 'expense';
  icon: (typeof ICON_KEYS)[number];
  color: string;
  sortOrder: number;
}

export class AuthRepository {
  constructor(private readonly db: Database) {}

  async hasAnyUser(): Promise<boolean> {
    const [row] = await this.db.select({ id: users.id }).from(users).limit(1);
    return Boolean(row);
  }

  /**
   * Atomically acquires an advisory lock, checks if any user exists,
   * inserts the owner user, and seeds default categories.
   * Returns `null` if an owner already exists.
   */
  async createOwnerWithSeedCategories(
    input: { email: string; passwordHash: string; displayName: string },
    seeds: SeedCategoryRecord[],
  ): Promise<UserRow | null> {
    return this.db.transaction(async (tx) => {
      await tx.execute(sql`SELECT pg_advisory_xact_lock(${REGISTRATION_LOCK_KEY})`);
      const [existing] = await tx.select({ id: users.id }).from(users).limit(1);
      if (existing) return null;

      const [created] = await tx
        .insert(users)
        .values({
          email: input.email,
          passwordHash: input.passwordHash,
          displayName: input.displayName,
        })
        .returning();
      if (!created) throw new Error('Failed to create user');

      if (seeds.length > 0) {
        await tx.insert(categories).values(seeds.map((s) => ({ ...s, userId: created.id })));
      }
      await tx.insert(appSettings).values({ userId: created.id });
      return created;
    });
  }

  async getOrCreateAppSettings(userId: string): Promise<AppSettingsRow> {
    const [existing] = await this.db
      .select()
      .from(appSettings)
      .where(eq(appSettings.userId, userId))
      .limit(1);
    if (existing) return existing;

    const [created] = await this.db
      .insert(appSettings)
      .values({ userId })
      .returning();
    return created!;
  }

  async updateAppSettings(
    userId: string,
    patch: {
      themeMode?: 'system' | 'light' | 'dark';
      language?: 'th' | 'en';
      useBuddhistEra?: boolean;
      privacyMode?: boolean;
      autoLockSeconds?: number;
    },
  ): Promise<AppSettingsRow> {
    await this.getOrCreateAppSettings(userId);
    const [updated] = await this.db
      .update(appSettings)
      .set({ ...patch, updatedAt: new Date() })
      .where(eq(appSettings.userId, userId))
      .returning();
    return updated!;
  }

  async findUserByEmail(email: string): Promise<UserRow | undefined> {
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(sql`lower(${users.email})`, email.toLowerCase()))
      .limit(1);
    return user;
  }

  async findUserById(id: string): Promise<UserRow | undefined> {
    const [user] = await this.db.select().from(users).where(eq(users.id, id)).limit(1);
    return user;
  }

  async updateUser(
    id: string,
    patch: { displayName?: string; timezone?: string },
  ): Promise<UserRow | undefined> {
    const [user] = await this.db
      .update(users)
      .set({ ...patch, updatedAt: new Date() })
      .where(eq(users.id, id))
      .returning();
    return user;
  }

  async updatePasswordAndRevokeSessions(userId: string, passwordHash: string): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx.update(users).set({ passwordHash, updatedAt: new Date() }).where(eq(users.id, userId));
      await tx
        .update(refreshTokens)
        .set({ revokedAt: new Date() })
        .where(and(eq(refreshTokens.userId, userId), isNull(refreshTokens.revokedAt)));
    });
  }

  async insertRefreshToken(record: {
    userId: string;
    tokenHash: string;
    familyId: string;
    expiresAt: Date;
    userAgent?: string;
  }): Promise<void> {
    await this.pruneStaleRefreshTokens();
    await this.db.insert(refreshTokens).values(record);
  }

  /**
   * Section 3.1 Storage Optimization: automatically deletes expired refresh tokens
   * and tokens revoked more than 7 days ago so dead session rows never accumulate.
   */
  private async pruneStaleRefreshTokens(): Promise<void> {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    await this.db
      .delete(refreshTokens)
      .where(
        or(
          lt(refreshTokens.expiresAt, now),
          lt(refreshTokens.revokedAt, sevenDaysAgo),
        ),
      );
  }

  async findRefreshTokenByHash(tokenHash: string) {
    const [stored] = await this.db
      .select()
      .from(refreshTokens)
      .where(eq(refreshTokens.tokenHash, tokenHash))
      .limit(1);
    return stored;
  }

  async revokeFamily(familyId: string): Promise<void> {
    await this.db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(and(eq(refreshTokens.familyId, familyId), isNull(refreshTokens.revokedAt)));
  }

  /**
   * Atomically inserts the replacement refresh token and marks the old token as revoked.
   * Returns `false` if the old token was concurrently revoked/used.
   */
  async rotateRefreshToken(
    oldTokenId: string,
    nextRecord: {
      userId: string;
      tokenHash: string;
      familyId: string;
      expiresAt: Date;
      userAgent?: string;
    },
  ): Promise<boolean> {
    return this.db.transaction(async (tx) => {
      const [newRow] = await tx
        .insert(refreshTokens)
        .values(nextRecord)
        .returning({ id: refreshTokens.id });

      const revoked = await tx
        .update(refreshTokens)
        .set({ revokedAt: new Date(), replacedById: newRow!.id })
        .where(and(eq(refreshTokens.id, oldTokenId), isNull(refreshTokens.revokedAt)))
        .returning({ id: refreshTokens.id });

      if (revoked.length === 0) {
        tx.rollback();
      }
      return true;
    });
  }

  async revokeRefreshTokenByHash(tokenHash: string): Promise<void> {
    await this.db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(and(eq(refreshTokens.tokenHash, tokenHash), isNull(refreshTokens.revokedAt)));
  }
}

