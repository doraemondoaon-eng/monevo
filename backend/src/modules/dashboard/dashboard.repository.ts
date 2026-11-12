import { and, asc, eq, isNull, sql } from 'drizzle-orm';
import { rowsOf, type Database } from '../../db/client.js';
import { accounts, categories, refreshTokens, transactions, users } from '../../db/schema.js';

export interface MonthlyCashflowRow {
  ym: string;
  income: number;
  expense: number;
}

export interface DailyCashflowRow {
  ymd: string;
  income: number;
  expense: number;
}

export interface YearlyCashflowRow {
  yr: string;
  income: number;
  expense: number;
}

export interface CategoryAggregateRow {
  categoryId: string | null;
  name: string | null;
  icon: string | null;
  color: string | null;
  amount: number;
  count: number;
}

export class DashboardRepository {
  constructor(private readonly db: Database) {}

  async getUserSettings(userId: string): Promise<{ baseCurrency: string; timezone: string } | undefined> {
    const [u] = await this.db
      .select({ baseCurrency: users.baseCurrency, timezone: users.timezone })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    return u;
  }

  async listActiveAccountsForCurrency(
    userId: string,
    currency: string,
  ): Promise<
    Array<{
      id: string;
      name: string;
      type: string;
      institution: string | null;
      color: string;
      icon: string;
      balance: number;
      includeInNetWorth: boolean;
    }>
  > {
    return this.db
      .select({
        id: accounts.id,
        name: accounts.name,
        type: accounts.type,
        institution: accounts.institution,
        color: accounts.color,
        icon: accounts.icon,
        balance: accounts.balance,
        includeInNetWorth: accounts.includeInNetWorth,
      })
      .from(accounts)
      .where(
        and(
          eq(accounts.userId, userId),
          eq(accounts.currency, currency),
          eq(accounts.isArchived, false),
          isNull(accounts.deletedAt),
        ),
      )
      .orderBy(asc(accounts.sortOrder), asc(accounts.createdAt));
  }

  async getAllTimeTotals(
    userId: string,
    currency: string,
  ): Promise<{ totalIncome: number; totalExpense: number }> {
    const res = await this.db.execute(sql`
      SELECT
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'income' THEN ${transactions.amount} ELSE 0 END), 0)::text AS total_income,
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'expense' THEN ${transactions.amount} ELSE 0 END), 0)::text AS total_expense
      FROM ${transactions}
      INNER JOIN ${accounts} ON ${accounts.id} = ${transactions.accountId}
      WHERE ${transactions.userId} = ${userId}
        AND ${transactions.deletedAt} IS NULL
        AND ${accounts.deletedAt} IS NULL
        AND ${accounts.isArchived} = FALSE
        AND ${accounts.currency} = ${currency}
        AND ${transactions.type} IN ('income', 'expense')
    `);
    const row = rowsOf<{ total_income: string; total_expense: string }>(res)[0];
    return {
      totalIncome: Number(row?.total_income ?? 0),
      totalExpense: Number(row?.total_expense ?? 0),
    };
  }

  async getMonthlyTotalsForRange(
    userId: string,
    currency: string,
    timezone: string,
    startMonth: string,
    endMonth: string,
  ): Promise<MonthlyCashflowRow[]> {
    const res = await this.db.execute(sql`
      SELECT
        to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM') AS ym,
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'income' THEN ${transactions.amount} ELSE 0 END), 0)::text AS income,
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'expense' THEN ${transactions.amount} ELSE 0 END), 0)::text AS expense
      FROM ${transactions}
      INNER JOIN ${accounts} ON ${accounts.id} = ${transactions.accountId}
      WHERE ${transactions.userId} = ${userId}
        AND ${transactions.deletedAt} IS NULL
        AND ${accounts.deletedAt} IS NULL
        AND ${accounts.isArchived} = FALSE
        AND ${accounts.currency} = ${currency}
        AND ${transactions.type} IN ('income', 'expense')
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM') >= ${startMonth}
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM') <= ${endMonth}
      GROUP BY ym
    `);
    return rowsOf<{ ym: string; income: string; expense: string }>(res).map((r) => ({
      ym: r.ym,
      income: Number(r.income),
      expense: Number(r.expense),
    }));
  }

  async getDailyTotalsForRange(
    userId: string,
    currency: string,
    timezone: string,
    startDate: string,
    endDate: string,
  ): Promise<DailyCashflowRow[]> {
    const res = await this.db.execute(sql`
      SELECT
        to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM-DD') AS ymd,
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'income' THEN ${transactions.amount} ELSE 0 END), 0)::text AS income,
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'expense' THEN ${transactions.amount} ELSE 0 END), 0)::text AS expense
      FROM ${transactions}
      INNER JOIN ${accounts} ON ${accounts.id} = ${transactions.accountId}
      WHERE ${transactions.userId} = ${userId}
        AND ${transactions.deletedAt} IS NULL
        AND ${accounts.deletedAt} IS NULL
        AND ${accounts.isArchived} = FALSE
        AND ${accounts.currency} = ${currency}
        AND ${transactions.type} IN ('income', 'expense')
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM-DD') >= ${startDate}
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM-DD') <= ${endDate}
      GROUP BY ymd
    `);
    return rowsOf<{ ymd: string; income: string; expense: string }>(res).map((r) => ({
      ymd: r.ymd,
      income: Number(r.income),
      expense: Number(r.expense),
    }));
  }

  async getYearlyTotalsForRange(
    userId: string,
    currency: string,
    timezone: string,
    startYear: string,
    endYear: string,
  ): Promise<YearlyCashflowRow[]> {
    const res = await this.db.execute(sql`
      SELECT
        to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY') AS yr,
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'income' THEN ${transactions.amount} ELSE 0 END), 0)::text AS income,
        COALESCE(SUM(CASE WHEN ${transactions.type} = 'expense' THEN ${transactions.amount} ELSE 0 END), 0)::text AS expense
      FROM ${transactions}
      INNER JOIN ${accounts} ON ${accounts.id} = ${transactions.accountId}
      WHERE ${transactions.userId} = ${userId}
        AND ${transactions.deletedAt} IS NULL
        AND ${accounts.deletedAt} IS NULL
        AND ${accounts.isArchived} = FALSE
        AND ${accounts.currency} = ${currency}
        AND ${transactions.type} IN ('income', 'expense')
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY') >= ${startYear}
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY') <= ${endYear}
      GROUP BY yr
    `);
    return rowsOf<{ yr: string; income: string; expense: string }>(res).map((r) => ({
      yr: r.yr,
      income: Number(r.income),
      expense: Number(r.expense),
    }));
  }

  async getCategoryAggregates(
    userId: string,
    currency: string,
    timezone: string,
    month: string,
    type: 'income' | 'expense',
  ): Promise<CategoryAggregateRow[]> {
    const res = await this.db.execute(sql`
      SELECT
        ${categories.id} AS category_id,
        ${categories.name} AS name,
        ${categories.icon} AS icon,
        ${categories.color} AS color,
        COALESCE(SUM(${transactions.amount}), 0)::text AS amount,
        COUNT(${transactions.id})::int AS count
      FROM ${transactions}
      INNER JOIN ${accounts} ON ${accounts.id} = ${transactions.accountId}
      LEFT JOIN ${categories} ON ${categories.id} = ${transactions.categoryId}
      WHERE ${transactions.userId} = ${userId}
        AND ${transactions.deletedAt} IS NULL
        AND ${accounts.deletedAt} IS NULL
        AND ${accounts.isArchived} = FALSE
        AND ${accounts.currency} = ${currency}
        AND ${transactions.type} = ${type}
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM') = ${month}
      GROUP BY ${categories.id}, ${categories.name}, ${categories.icon}, ${categories.color}
      ORDER BY SUM(${transactions.amount}) DESC
    `);
    return rowsOf<{
      category_id: string | null;
      name: string | null;
      icon: string | null;
      color: string | null;
      amount: string;
      count: number;
    }>(res).map((r) => ({
      categoryId: r.category_id,
      name: r.name,
      icon: r.icon,
      color: r.color,
      amount: Number(r.amount),
      count: Number(r.count),
    }));
  }

  async getDailyNetWorthDeltasFromDate(
    userId: string,
    currency: string,
    timezone: string,
    startDate: string,
  ): Promise<Array<{ ymd: string; delta: number }>> {
    const res = await this.db.execute(sql`
      SELECT
        to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM-DD') AS ymd,
        COALESCE(SUM(
          CASE
            WHEN ${transactions.type} = 'income' AND src.include_in_net_worth = TRUE AND src.is_archived = FALSE AND src.deleted_at IS NULL AND src.currency = ${currency}
              THEN ${transactions.amount}
            WHEN ${transactions.type} = 'expense' AND src.include_in_net_worth = TRUE AND src.is_archived = FALSE AND src.deleted_at IS NULL AND src.currency = ${currency}
              THEN -${transactions.amount}
            WHEN ${transactions.type} = 'transfer' THEN
              (CASE WHEN src.include_in_net_worth = TRUE AND src.is_archived = FALSE AND src.deleted_at IS NULL AND src.currency = ${currency} THEN -${transactions.amount} ELSE 0 END)
              + (CASE WHEN dst.id IS NOT NULL AND dst.include_in_net_worth = TRUE AND dst.is_archived = FALSE AND dst.deleted_at IS NULL AND dst.currency = ${currency} THEN COALESCE(${transactions.toAmount}, ${transactions.amount}) ELSE 0 END)
            ELSE 0
          END
        ), 0)::text AS delta
      FROM ${transactions}
      INNER JOIN ${accounts} src ON src.id = ${transactions.accountId}
      LEFT JOIN ${accounts} dst ON dst.id = ${transactions.toAccountId}
      WHERE ${transactions.userId} = ${userId}
        AND ${transactions.deletedAt} IS NULL
        AND to_char(${transactions.occurredAt} AT TIME ZONE ${timezone}, 'YYYY-MM-DD') >= ${startDate}
      GROUP BY ymd
    `);
    return rowsOf<{ ymd: string; delta: string }>(res).map((r) => ({
      ymd: r.ymd,
      delta: Number(r.delta),
    }));
  }

  /**
   * Section 12 Cloud Hosting Optimization:
   * Inspects actual PostgreSQL database size (`pg_database_size(current_database())`)
   * and row counts across tables to monitor the 512 MB Free-Tier storage quota.
   */
  async getDatabaseStorageStats(userId: string): Promise<{
    databaseBytes: number;
    accountsCount: number;
    categoriesCount: number;
    transactionsCount: number;
    refreshTokensCount: number;
  }> {
    const res = await this.db.execute(sql`
      SELECT
        pg_database_size(current_database())::text AS db_bytes,
        (SELECT COUNT(*)::int FROM ${accounts} WHERE ${accounts.userId} = ${userId} AND ${accounts.deletedAt} IS NULL) AS accounts_count,
        (SELECT COUNT(*)::int FROM ${categories} WHERE ${categories.userId} = ${userId} AND ${categories.deletedAt} IS NULL) AS categories_count,
        (SELECT COUNT(*)::int FROM ${transactions} WHERE ${transactions.userId} = ${userId} AND ${transactions.deletedAt} IS NULL) AS transactions_count,
        (SELECT COUNT(*)::int FROM ${refreshTokens} WHERE ${refreshTokens.userId} = ${userId}) AS refresh_tokens_count
    `);
    const row = rowsOf<{
      db_bytes: string;
      accounts_count: number;
      categories_count: number;
      transactions_count: number;
      refresh_tokens_count: number;
    }>(res)[0];

    return {
      databaseBytes: Number(row?.db_bytes ?? 0),
      accountsCount: Number(row?.accounts_count ?? 0),
      categoriesCount: Number(row?.categories_count ?? 0),
      transactionsCount: Number(row?.transactions_count ?? 0),
      refreshTokensCount: Number(row?.refresh_tokens_count ?? 0),
    };
  }
}

