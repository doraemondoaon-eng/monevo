import { sql } from 'drizzle-orm';
import {
  boolean,
  char,
  check,
  customType,
  index,
  integer,
  pgEnum,
  pgTable,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

/**
 * Section 5 Database Design:
 * Monetary values are stored using PostgreSQL `NUMERIC(18, 0)` in integer minor units
 * (satang), completely eliminating floating-point (`REAL` / `DOUBLE PRECISION`) rounding errors.
 * `fromDriver` and `toDriver` map between PostgreSQL `numeric(18, 0)` and exact JS safe integers.
 */
export const moneyNumeric = customType<{ data: number; driverData: string | number }>({
  dataType() {
    return 'numeric(18, 0)';
  },
  toDriver(value: number): string {
    if (!Number.isSafeInteger(value)) {
      throw new Error(`Invalid monetary minor-unit amount: ${value}`);
    }
    return String(value);
  },
  fromDriver(value: string | number): number {
    return Number(value);
  },
});

const timestamps = {
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
};

export const accountTypeEnum = pgEnum('account_type', [
  'bank',
  'cash',
  'credit_card',
  'e_wallet',
  'investment',
  'other',
]);
export const categoryTypeEnum = pgEnum('category_type', ['income', 'expense']);
export const transactionTypeEnum = pgEnum('transaction_type', ['income', 'expense', 'transfer']);

export const users = pgTable(
  'users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    email: varchar('email', { length: 254 }).notNull(),
    passwordHash: text('password_hash').notNull(),
    displayName: varchar('display_name', { length: 80 }).notNull(),
    baseCurrency: char('base_currency', { length: 3 }).notNull().default('THB'),
    timezone: varchar('timezone', { length: 64 }).notNull().default('Asia/Bangkok'),
    ...timestamps,
  },
  (t) => [uniqueIndex('users_email_lower_uq').on(sql`lower(${t.email})`)],
);

/**
 * Canonical lookup table for transaction types (`income`, `expense`, `transfer`).
 * Referenced via Foreign Key by `transactions.type`.
 */
export const transactionTypes = pgTable('transaction_types', {
  code: transactionTypeEnum('code').primaryKey(),
  labelTh: varchar('label_th', { length: 40 }).notNull(),
  labelEn: varchar('label_en', { length: 40 }).notNull(),
  /** +1 for income, -1 for expense, 0 for transfer (net across accounts). */
  balanceDirection: smallint('balance_direction').notNull(),
  requiresCategory: boolean('requires_category').notNull(),
  requiresDestinationAccount: boolean('requires_destination_account').notNull(),
  sortOrder: smallint('sort_order').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

/**
 * Per-user application settings (`1:1` relationship with `users`).
 */
export const appSettings = pgTable(
  'app_settings',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    themeMode: varchar('theme_mode', { length: 16 }).notNull().default('system'),
    language: varchar('language', { length: 8 }).notNull().default('th'),
    useBuddhistEra: boolean('use_buddhist_era').notNull().default(true),
    privacyMode: boolean('privacy_mode').notNull().default(false),
    autoLockSeconds: integer('auto_lock_seconds').notNull().default(60),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('app_settings_user_uq').on(t.userId),
    check('app_settings_theme_chk', sql`${t.themeMode} IN ('system', 'light', 'dark')`),
    check('app_settings_lang_chk', sql`${t.language} IN ('th', 'en')`),
    check('app_settings_autolock_chk', sql`${t.autoLockSeconds} BETWEEN 0 AND 3600`),
  ],
);

export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** SHA-256 of the opaque token; the raw token is never stored. */
    tokenHash: varchar('token_hash', { length: 64 }).notNull(),
    /** All tokens produced by rotating one login share a family (for reuse detection). */
    familyId: uuid('family_id').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
    replacedById: uuid('replaced_by_id'),
    userAgent: varchar('user_agent', { length: 255 }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('refresh_tokens_hash_uq').on(t.tokenHash),
    index('refresh_tokens_user_idx').on(t.userId),
    index('refresh_tokens_family_idx').on(t.familyId),
  ],
);

export const accounts = pgTable(
  'accounts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    name: varchar('name', { length: 80 }).notNull(),
    type: accountTypeEnum('type').notNull(),
    institution: varchar('institution', { length: 80 }),
    accountNumberLast4: varchar('account_number_last4', { length: 4 }),
    currency: char('currency', { length: 3 }).notNull().default('THB'),
    openingBalance: moneyNumeric('opening_balance').notNull().default(0),
    /** Cached balance = opening_balance + ledger effects; maintained atomically, verifiable via reconcile. */
    balance: moneyNumeric('balance').notNull().default(0),
    color: varchar('color', { length: 7 }).notNull().default('#4F46E5'),
    icon: varchar('icon', { length: 40 }).notNull().default('account_balance'),
    includeInNetWorth: boolean('include_in_net_worth').notNull().default(true),
    isArchived: boolean('is_archived').notNull().default(false),
    sortOrder: integer('sort_order').notNull().default(0),
    ...timestamps,
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [
    index('accounts_user_idx').on(t.userId),
    check('accounts_last4_chk', sql`${t.accountNumberLast4} IS NULL OR ${t.accountNumberLast4} ~ '^[0-9]{4}$'`),
  ],
);

export const categories = pgTable(
  'categories',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    name: varchar('name', { length: 60 }).notNull(),
    type: categoryTypeEnum('type').notNull(),
    icon: varchar('icon', { length: 40 }).notNull().default('more_horiz'),
    color: varchar('color', { length: 7 }).notNull().default('#64748B'),
    isArchived: boolean('is_archived').notNull().default(false),
    sortOrder: integer('sort_order').notNull().default(0),
    ...timestamps,
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [index('categories_user_type_idx').on(t.userId, t.type)],
);

export const transactions = pgTable(
  'transactions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    type: transactionTypeEnum('type')
      .notNull()
      .references(() => transactionTypes.code, { onDelete: 'restrict' }),
    amount: moneyNumeric('amount').notNull(),
    currency: char('currency', { length: 3 }).notNull(),
    accountId: uuid('account_id')
      .notNull()
      .references(() => accounts.id, { onDelete: 'restrict' }),
    toAccountId: uuid('to_account_id').references(() => accounts.id, { onDelete: 'restrict' }),
    /** Reserved for future cross-currency transfers (amount credited to to_account). */
    toAmount: moneyNumeric('to_amount'),
    categoryId: uuid('category_id').references(() => categories.id, { onDelete: 'restrict' }),
    occurredAt: timestamp('occurred_at', { withTimezone: true }).notNull().defaultNow(),
    payee: varchar('payee', { length: 120 }),
    note: varchar('note', { length: 500 }),
    ...timestamps,
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (t) => [
    index('transactions_user_occurred_idx').on(t.userId, t.occurredAt.desc(), t.id.desc()),
    index('transactions_account_occurred_idx').on(t.accountId, t.occurredAt),
    index('transactions_to_account_occurred_idx').on(t.toAccountId, t.occurredAt),
    index('transactions_category_idx').on(t.categoryId),
    check('transactions_amount_positive_chk', sql`${t.amount} > 0`),
    check(
      'transactions_shape_chk',
      sql`(${t.type} = 'transfer' AND ${t.toAccountId} IS NOT NULL AND ${t.categoryId} IS NULL AND ${t.toAccountId} <> ${t.accountId})
          OR (${t.type} <> 'transfer' AND ${t.toAccountId} IS NULL)`,
    ),
  ],
);

export type UserRow = typeof users.$inferSelect;
export type TransactionTypeRow = typeof transactionTypes.$inferSelect;
export type AppSettingsRow = typeof appSettings.$inferSelect;
export type AccountRow = typeof accounts.$inferSelect;
export type CategoryRow = typeof categories.$inferSelect;
export type TransactionRow = typeof transactions.$inferSelect;
