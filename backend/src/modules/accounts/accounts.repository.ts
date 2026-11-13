import { and, asc, eq, isNull, or, sql } from 'drizzle-orm';
import { rowsOf, type Database } from '../../db/client.js';
import { accounts, transactions, type AccountRow } from '../../db/schema.js';

export class AccountsRepository {
  constructor(private readonly db: Database) {}

  async listByUser(userId: string, includeArchived: boolean): Promise<AccountRow[]> {
    return this.db
      .select()
      .from(accounts)
      .where(
        and(
          eq(accounts.userId, userId),
          isNull(accounts.deletedAt),
          includeArchived ? undefined : eq(accounts.isArchived, false),
        ),
      )
      .orderBy(asc(accounts.sortOrder), asc(accounts.createdAt));
  }

  async findByIdAndUser(userId: string, id: string, executor: Database = this.db): Promise<AccountRow | undefined> {
    const [row] = await executor
      .select()
      .from(accounts)
      .where(and(eq(accounts.id, id), eq(accounts.userId, userId), isNull(accounts.deletedAt)))
      .limit(1);
    return row;
  }

  async insert(record: {
    userId: string;
    name: string;
    type: AccountRow['type'];
    institution: string | null;
    accountNumberLast4: string | null;
    currency: string;
    openingBalance: number;
    balance: number;
    color?: string;
    icon: string;
    includeInNetWorth: boolean;
  }): Promise<AccountRow> {
    const [row] = await this.db.insert(accounts).values(record).returning();
    return row!;
  }

  async update(
    userId: string,
    id: string,
    patch: {
      name?: string;
      type?: AccountRow['type'];
      institution?: string | null;
      accountNumberLast4?: string | null;
      openingBalance?: number;
      color?: string;
      icon?: string;
      includeInNetWorth?: boolean;
      isArchived?: boolean;
      sortOrder?: number;
    },
  ): Promise<AccountRow> {
    const { openingBalance, ...rest } = patch;
    const [row] = await this.db
      .update(accounts)
      .set({
        ...rest,
        ...(openingBalance !== undefined
          ? {
              openingBalance,
              balance: sql`${accounts.balance} + (${openingBalance}::numeric(18, 0) - ${accounts.openingBalance})`,
            }
          : {}),
        updatedAt: new Date(),
      })
      .where(and(eq(accounts.id, id), eq(accounts.userId, userId)))
      .returning();
    return row!;
  }

  async hasActiveTransactions(userId: string, accountId: string): Promise<boolean> {
    const [used] = await this.db
      .select({ id: transactions.id })
      .from(transactions)
      .where(
        and(
          eq(transactions.userId, userId),
          isNull(transactions.deletedAt),
          or(eq(transactions.accountId, accountId), eq(transactions.toAccountId, accountId)),
        ),
      )
      .limit(1);
    return Boolean(used);
  }

  async softDelete(userId: string, id: string): Promise<void> {
    await this.db
      .update(accounts)
      .set({ deletedAt: new Date(), updatedAt: new Date() })
      .where(and(eq(accounts.id, id), eq(accounts.userId, userId)));
  }

  async softDeleteCascade(userId: string, id: string): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx
        .update(transactions)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(
          and(
            eq(transactions.userId, userId),
            isNull(transactions.deletedAt),
            or(eq(transactions.accountId, id), eq(transactions.toAccountId, id)),
          ),
        );
      await tx
        .update(accounts)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(accounts.id, id), eq(accounts.userId, userId)));
    });
  }

  async computeLedgerDelta(userId: string, accountId: string): Promise<number> {
    const result = await this.db.execute(sql`
      SELECT COALESCE(SUM(
        CASE
          WHEN ${transactions.type} = 'income'   AND ${transactions.accountId} = ${accountId} THEN ${transactions.amount}
          WHEN ${transactions.type} = 'expense'  AND ${transactions.accountId} = ${accountId} THEN -${transactions.amount}
          WHEN ${transactions.type} = 'transfer' AND ${transactions.accountId} = ${accountId} THEN -${transactions.amount}
          WHEN ${transactions.type} = 'transfer' AND ${transactions.toAccountId} = ${accountId}
            THEN COALESCE(${transactions.toAmount}, ${transactions.amount})
          ELSE 0
        END), 0)::text AS delta
      FROM ${transactions}
      WHERE ${transactions.userId} = ${userId}
        AND ${transactions.deletedAt} IS NULL
        AND (${transactions.accountId} = ${accountId} OR ${transactions.toAccountId} = ${accountId})
    `);
    return Number(rowsOf<{ delta: string }>(result)[0]?.delta ?? 0);
  }

  async setBalance(accountId: string, balance: number): Promise<AccountRow> {
    const [row] = await this.db
      .update(accounts)
      .set({ balance, updatedAt: new Date() })
      .where(eq(accounts.id, accountId))
      .returning();
    return row!;
  }
}

