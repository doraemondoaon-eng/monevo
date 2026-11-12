import { AppError } from '../../common/errors.js';
import type { Database } from '../../db/client.js';
import type { AccountRow } from '../../db/schema.js';
import type { AccountsRepository } from './accounts.repository.js';
import type { CreateAccountInput, UpdateAccountInput } from './accounts.schemas.js';

export function toAccountDto(a: AccountRow) {
  return {
    id: a.id,
    name: a.name,
    type: a.type,
    institution: a.institution,
    accountNumberLast4: a.accountNumberLast4,
    currency: a.currency,
    openingBalance: a.openingBalance,
    balance: a.balance,
    color: a.color,
    icon: a.icon,
    includeInNetWorth: a.includeInNetWorth,
    isArchived: a.isArchived,
    sortOrder: a.sortOrder,
    createdAt: a.createdAt.toISOString(),
    updatedAt: a.updatedAt.toISOString(),
  };
}

const DEFAULT_ICON: Record<AccountRow['type'], string> = {
  bank: 'account_balance',
  cash: 'payments',
  credit_card: 'credit_card',
  e_wallet: 'phone_android',
  investment: 'trending_up',
  other: 'wallet',
};

export class AccountsService {
  constructor(private readonly repo: AccountsRepository) {}

  async list(userId: string, includeArchived = false) {
    const rows = await this.repo.listByUser(userId, includeArchived);
    return rows.map(toAccountDto);
  }

  /** Loads an account owned by the user (supports passing a transaction executor). */
  async findOwned(userId: string, id: string, executor?: Database): Promise<AccountRow> {
    const row = await this.repo.findByIdAndUser(userId, id, executor);
    if (!row) throw AppError.notFound('Account');
    return row;
  }

  async get(userId: string, id: string) {
    return toAccountDto(await this.findOwned(userId, id));
  }

  async create(userId: string, input: CreateAccountInput) {
    const opening = input.openingBalance ?? 0;
    const row = await this.repo.insert({
      userId,
      name: input.name,
      type: input.type,
      institution: input.institution ?? null,
      accountNumberLast4: input.accountNumberLast4 ?? null,
      currency: input.currency ?? 'THB',
      openingBalance: opening,
      balance: opening,
      color: input.color ?? undefined,
      icon: input.icon ?? DEFAULT_ICON[input.type],
      includeInNetWorth: input.includeInNetWorth ?? true,
    });
    return toAccountDto(row);
  }

  async update(userId: string, id: string, input: UpdateAccountInput) {
    await this.findOwned(userId, id);
    const row = await this.repo.update(userId, id, input);
    return toAccountDto(row);
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    if (await this.repo.hasActiveTransactions(userId, id)) {
      throw AppError.conflict('ACCOUNT_HAS_TRANSACTIONS', 'Account has transactions; archive it instead');
    }
    await this.repo.softDelete(userId, id);
  }

  /** Recomputes the cached balance from the ledger (source of truth). */
  async reconcile(userId: string, id: string) {
    const account = await this.findOwned(userId, id);
    const delta = await this.repo.computeLedgerDelta(userId, id);
    const row = await this.repo.setBalance(id, account.openingBalance + delta);
    return toAccountDto(row);
  }
}
