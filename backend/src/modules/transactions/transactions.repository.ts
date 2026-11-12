import { and, asc, desc, eq, gte, ilike, isNull, lt, or, sql, type SQL } from 'drizzle-orm';
import type { Database } from '../../db/client.js';
import {
  accounts,
  transactions,
  transactionTypes,
  type TransactionRow,
  type TransactionTypeRow,
} from '../../db/schema.js';

function escapeLike(input: string): string {
  return input.replace(/[\\%_]/g, (m) => `\\${m}`);
}

export interface TransactionFilters {
  from?: Date;
  to?: Date;
  type?: 'income' | 'expense' | 'transfer';
  accountId?: string;
  categoryId?: string;
  q?: string;
  cursor?: { occurredAt: Date; id: string };
  limit: number;
}

export class TransactionsRepository {
  constructor(private readonly db: Database) {}

  async runInTransaction<T>(fn: (txDb: Database) => Promise<T>): Promise<T> {
    return this.db.transaction(async (tx) => fn(tx as unknown as Database));
  }

  async listByUser(userId: string, filters: TransactionFilters): Promise<TransactionRow[]> {
    const conditions: (SQL | undefined)[] = [
      eq(transactions.userId, userId),
      isNull(transactions.deletedAt),
    ];

    if (filters.from) conditions.push(gte(transactions.occurredAt, filters.from));
    if (filters.to) conditions.push(lt(transactions.occurredAt, filters.to));
    if (filters.type) conditions.push(eq(transactions.type, filters.type));
    if (filters.accountId) {
      conditions.push(
        or(eq(transactions.accountId, filters.accountId), eq(transactions.toAccountId, filters.accountId)),
      );
    }
    if (filters.categoryId) conditions.push(eq(transactions.categoryId, filters.categoryId));
    if (filters.q && filters.q.length > 0) {
      const pattern = `%${escapeLike(filters.q)}%`;
      conditions.push(or(ilike(transactions.payee, pattern), ilike(transactions.note, pattern)));
    }
    if (filters.cursor) {
      const c = filters.cursor;
      conditions.push(
        or(
          lt(transactions.occurredAt, c.occurredAt),
          and(eq(transactions.occurredAt, c.occurredAt), lt(transactions.id, c.id)),
        ),
      );
    }

    return this.db
      .select()
      .from(transactions)
      .where(and(...conditions))
      .orderBy(desc(transactions.occurredAt), desc(transactions.id))
      .limit(filters.limit);
  }

  async findByIdAndUser(
    userId: string,
    id: string,
    executor: Database = this.db,
  ): Promise<TransactionRow | undefined> {
    const [row] = await executor
      .select()
      .from(transactions)
      .where(and(eq(transactions.id, id), eq(transactions.userId, userId), isNull(transactions.deletedAt)))
      .limit(1);
    return row;
  }

  async insert(
    record: {
      userId: string;
      type: 'income' | 'expense' | 'transfer';
      amount: number;
      currency: string;
      accountId: string;
      toAccountId: string | null;
      toAmount: number | null;
      categoryId: string | null;
      occurredAt: Date;
      payee: string | null;
      note: string | null;
    },
    executor: Database = this.db,
  ): Promise<TransactionRow> {
    const [created] = await executor.insert(transactions).values(record).returning();
    return created!;
  }

  async update(
    id: string,
    patch: {
      type: 'income' | 'expense' | 'transfer';
      amount: number;
      currency: string;
      accountId: string;
      toAccountId: string | null;
      toAmount: number | null;
      categoryId: string | null;
      occurredAt: Date;
      payee: string | null;
      note: string | null;
    },
    executor: Database = this.db,
  ): Promise<TransactionRow> {
    const [updated] = await executor
      .update(transactions)
      .set({ ...patch, updatedAt: new Date() })
      .where(eq(transactions.id, id))
      .returning();
    return updated!;
  }

  async softDelete(id: string, executor: Database = this.db): Promise<void> {
    await executor
      .update(transactions)
      .set({ deletedAt: new Date(), updatedAt: new Date() })
      .where(eq(transactions.id, id));
  }

  async adjustAccountBalance(accountId: string, delta: number, executor: Database = this.db): Promise<void> {
    await executor
      .update(accounts)
      .set({ balance: sql`${accounts.balance} + ${delta}::numeric(18, 0)`, updatedAt: new Date() })
      .where(eq(accounts.id, accountId));
  }

  async listTransactionTypes(): Promise<TransactionTypeRow[]> {
    return this.db
      .select()
      .from(transactionTypes)
      .orderBy(asc(transactionTypes.sortOrder));
  }
}

