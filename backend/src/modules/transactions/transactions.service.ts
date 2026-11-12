import { AppError } from '../../common/errors.js';
import type { Database } from '../../db/client.js';
import type { TransactionRow } from '../../db/schema.js';
import type { AccountsService } from '../accounts/accounts.service.js';
import type { CategoriesService } from '../categories/categories.service.js';
import type { TransactionsRepository } from './transactions.repository.js';
import type {
  CreateTransactionInput,
  ListTransactionsQuery,
  UpdateTransactionInput,
} from './transactions.schemas.js';

export function toTransactionDto(t: TransactionRow) {
  return {
    id: t.id,
    type: t.type,
    amount: t.amount,
    currency: t.currency,
    accountId: t.accountId,
    toAccountId: t.toAccountId,
    categoryId: t.categoryId,
    occurredAt: t.occurredAt.toISOString(),
    payee: t.payee,
    note: t.note,
    createdAt: t.createdAt.toISOString(),
    updatedAt: t.updatedAt.toISOString(),
  };
}

interface CursorPayload {
  t: string;
  id: string;
}

function encodeCursor(row: TransactionRow): string {
  const payload: CursorPayload = { t: row.occurredAt.toISOString(), id: row.id };
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

function decodeCursor(raw: string): { occurredAt: Date; id: string } {
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as CursorPayload;
    const occurredAt = new Date(parsed.t);
    if (!parsed.id || Number.isNaN(occurredAt.getTime())) {
      throw new Error('bad cursor');
    }
    return { occurredAt, id: parsed.id };
  } catch {
    throw AppError.badRequest('Invalid pagination cursor');
  }
}

export class TransactionsService {
  constructor(
    private readonly repo: TransactionsRepository,
    private readonly accountsService: AccountsService,
    private readonly categoriesService: CategoriesService,
  ) {}

  async listTypes() {
    const rows = await this.repo.listTransactionTypes();
    return rows.map((r) => ({
      code: r.code,
      labelTh: r.labelTh,
      labelEn: r.labelEn,
      balanceDirection: r.balanceDirection,
      requiresCategory: r.requiresCategory,
      requiresDestinationAccount: r.requiresDestinationAccount,
      sortOrder: r.sortOrder,
    }));
  }

  async list(userId: string, query: ListTransactionsQuery) {
    const limit = query.limit ?? 30;
    const rows = await this.repo.listByUser(userId, {
      from: query.from ? new Date(query.from) : undefined,
      to: query.to ? new Date(query.to) : undefined,
      type: query.type,
      accountId: query.accountId,
      categoryId: query.categoryId,
      q: query.q,
      cursor: query.cursor ? decodeCursor(query.cursor) : undefined,
      limit: limit + 1,
    });

    const hasMore = rows.length > limit;
    const slice = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? encodeCursor(slice[slice.length - 1]!) : null;

    return {
      data: slice.map(toTransactionDto),
      nextCursor,
    };
  }

  async findOwned(userId: string, id: string, executor?: Database): Promise<TransactionRow> {
    const row = await this.repo.findByIdAndUser(userId, id, executor);
    if (!row) throw AppError.notFound('Transaction');
    return row;
  }

  async get(userId: string, id: string) {
    return toTransactionDto(await this.findOwned(userId, id));
  }

  async create(userId: string, input: CreateTransactionInput) {
    const row = await this.repo.runInTransaction(async (txDb) => {
      const validated = await this.validateAndResolve(
        userId,
        {
          type: input.type,
          amount: input.amount,
          accountId: input.accountId,
          toAccountId: input.toAccountId ?? null,
          categoryId: input.categoryId ?? null,
        },
        txDb,
      );

      const created = await this.repo.insert(
        {
          userId,
          type: validated.type,
          amount: validated.amount,
          currency: validated.currency,
          accountId: validated.accountId,
          toAccountId: validated.toAccountId,
          toAmount: validated.type === 'transfer' ? validated.amount : null,
          categoryId: validated.categoryId,
          occurredAt: input.occurredAt ? new Date(input.occurredAt) : new Date(),
          payee: input.payee ?? null,
          note: input.note ?? null,
        },
        txDb,
      );

      await this.applyBalanceDelta(txDb, created, 1);
      return created;
    });

    return toTransactionDto(row);
  }

  async update(userId: string, id: string, input: UpdateTransactionInput) {
    const row = await this.repo.runInTransaction(async (txDb) => {
      const existing = await this.findOwned(userId, id, txDb);

      const nextType = input.type ?? existing.type;
      const nextAmount = input.amount ?? existing.amount;
      const nextAccountId = input.accountId ?? existing.accountId;
      const nextToAccountId =
        nextType === 'transfer'
          ? input.toAccountId !== undefined
            ? input.toAccountId
            : existing.toAccountId
          : null;
      const nextCategoryId =
        nextType === 'transfer'
          ? null
          : input.categoryId !== undefined
            ? input.categoryId
            : existing.categoryId;

      if (nextType !== 'transfer' && input.toAccountId) {
        throw AppError.validation('toAccountId is only valid for transfers', [
          { path: 'toAccountId', message: 'Must be omitted for income/expense' },
        ]);
      }
      if (nextType === 'transfer' && input.categoryId) {
        throw AppError.validation('categoryId is not allowed on transfers', [
          { path: 'categoryId', message: 'Transfers cannot have a category' },
        ]);
      }

      const validated = await this.validateAndResolve(
        userId,
        {
          type: nextType,
          amount: nextAmount,
          accountId: nextAccountId,
          toAccountId: nextToAccountId ?? null,
          categoryId: nextCategoryId ?? null,
        },
        txDb,
      );

      // Reverse old ledger effect, update row, then apply new ledger effect.
      await this.applyBalanceDelta(txDb, existing, -1);

      const updated = await this.repo.update(
        id,
        {
          type: validated.type,
          amount: validated.amount,
          currency: validated.currency,
          accountId: validated.accountId,
          toAccountId: validated.toAccountId,
          toAmount: validated.type === 'transfer' ? validated.amount : null,
          categoryId: validated.categoryId,
          occurredAt: input.occurredAt ? new Date(input.occurredAt) : existing.occurredAt,
          payee: input.payee !== undefined ? input.payee : existing.payee,
          note: input.note !== undefined ? input.note : existing.note,
        },
        txDb,
      );

      await this.applyBalanceDelta(txDb, updated, 1);
      return updated;
    });

    return toTransactionDto(row);
  }

  async remove(userId: string, id: string) {
    await this.repo.runInTransaction(async (txDb) => {
      const existing = await this.findOwned(userId, id, txDb);
      await this.applyBalanceDelta(txDb, existing, -1);
      await this.repo.softDelete(id, txDb);
    });
  }

  private async validateAndResolve(
    userId: string,
    spec: {
      type: 'income' | 'expense' | 'transfer';
      amount: number;
      accountId: string;
      toAccountId: string | null;
      categoryId: string | null;
    },
    txDb: Database,
  ) {
    const fromAccount = await this.accountsService.findOwned(userId, spec.accountId, txDb);

    if (spec.type === 'transfer') {
      if (!spec.toAccountId) {
        throw AppError.validation('Transfer requires toAccountId', [
          { path: 'toAccountId', message: 'Destination account is required for transfers' },
        ]);
      }
      if (spec.toAccountId === spec.accountId) {
        throw AppError.validation('Cannot transfer to the same account', [
          { path: 'toAccountId', message: 'Destination account must differ from source account' },
        ]);
      }
      if (spec.categoryId) {
        throw AppError.validation('Transfers cannot have a category', [
          { path: 'categoryId', message: 'Must be null for transfers' },
        ]);
      }
      const toAccount = await this.accountsService.findOwned(userId, spec.toAccountId, txDb);
      if (toAccount.currency !== fromAccount.currency) {
        throw AppError.validation('Cross-currency transfers are not yet supported', [
          { path: 'toAccountId', message: 'Both accounts must have the same currency' },
        ]);
      }
      return {
        type: spec.type,
        amount: spec.amount,
        currency: fromAccount.currency,
        accountId: fromAccount.id,
        toAccountId: toAccount.id,
        categoryId: null,
      };
    }

    if (spec.toAccountId) {
      throw AppError.validation('toAccountId is only valid for transfers', [
        { path: 'toAccountId', message: 'Must be null for income/expense' },
      ]);
    }
    if (spec.categoryId) {
      const cat = await this.categoriesService.findOwned(userId, spec.categoryId, txDb);
      if (cat.type !== spec.type) {
        throw AppError.validation(`Category type (${cat.type}) does not match transaction type (${spec.type})`, [
          { path: 'categoryId', message: `Expected a ${spec.type} category` },
        ]);
      }
    }

    return {
      type: spec.type,
      amount: spec.amount,
      currency: fromAccount.currency,
      accountId: fromAccount.id,
      toAccountId: null,
      categoryId: spec.categoryId,
    };
  }

  /**
   * Adjusts cached account balance(s). `direction` is `+1` when applying a transaction
   * and `-1` when reversing it (before update or delete).
   */
  private async applyBalanceDelta(txDb: Database, t: TransactionRow, direction: 1 | -1) {
    if (t.type === 'income') {
      await this.repo.adjustAccountBalance(t.accountId, t.amount * direction, txDb);
    } else if (t.type === 'expense') {
      await this.repo.adjustAccountBalance(t.accountId, -t.amount * direction, txDb);
    } else {
      await this.repo.adjustAccountBalance(t.accountId, -t.amount * direction, txDb);
      if (t.toAccountId) {
        await this.repo.adjustAccountBalance(t.toAccountId, (t.toAmount ?? t.amount) * direction, txDb);
      }
    }
  }
}
