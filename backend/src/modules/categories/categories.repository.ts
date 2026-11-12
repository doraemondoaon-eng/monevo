import { and, asc, eq, isNull } from 'drizzle-orm';
import type { Database } from '../../db/client.js';
import { categories, transactions, type CategoryRow } from '../../db/schema.js';

export class CategoriesRepository {
  constructor(private readonly db: Database) {}

  async listByUser(
    userId: string,
    opts: { type?: 'income' | 'expense'; includeArchived?: boolean } = {},
  ): Promise<CategoryRow[]> {
    return this.db
      .select()
      .from(categories)
      .where(
        and(
          eq(categories.userId, userId),
          isNull(categories.deletedAt),
          opts.type ? eq(categories.type, opts.type) : undefined,
          opts.includeArchived ? undefined : eq(categories.isArchived, false),
        ),
      )
      .orderBy(asc(categories.sortOrder), asc(categories.createdAt));
  }

  async findByIdAndUser(
    userId: string,
    id: string,
    executor: Database = this.db,
  ): Promise<CategoryRow | undefined> {
    const [row] = await executor
      .select()
      .from(categories)
      .where(and(eq(categories.id, id), eq(categories.userId, userId), isNull(categories.deletedAt)))
      .limit(1);
    return row;
  }

  async insert(record: {
    userId: string;
    name: string;
    type: CategoryRow['type'];
    icon: string;
    color: string;
  }): Promise<CategoryRow> {
    const [row] = await this.db.insert(categories).values(record).returning();
    return row!;
  }

  async update(
    userId: string,
    id: string,
    patch: {
      name?: string;
      icon?: string;
      color?: string;
      isArchived?: boolean;
      sortOrder?: number;
    },
  ): Promise<CategoryRow> {
    const [row] = await this.db
      .update(categories)
      .set({ ...patch, updatedAt: new Date() })
      .where(and(eq(categories.id, id), eq(categories.userId, userId)))
      .returning();
    return row!;
  }

  async isUsedByTransactions(userId: string, categoryId: string): Promise<boolean> {
    const [inUse] = await this.db
      .select({ id: transactions.id })
      .from(transactions)
      .where(
        and(
          eq(transactions.userId, userId),
          eq(transactions.categoryId, categoryId),
          isNull(transactions.deletedAt),
        ),
      )
      .limit(1);
    return Boolean(inUse);
  }

  async softDelete(userId: string, id: string): Promise<void> {
    await this.db
      .update(categories)
      .set({ deletedAt: new Date(), updatedAt: new Date() })
      .where(and(eq(categories.id, id), eq(categories.userId, userId)));
  }
}

