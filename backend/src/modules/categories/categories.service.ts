import { AppError } from '../../common/errors.js';
import type { Database } from '../../db/client.js';
import type { CategoryRow } from '../../db/schema.js';
import type { CategoriesRepository } from './categories.repository.js';
import type { CreateCategoryInput, UpdateCategoryInput } from './categories.schemas.js';

export function toCategoryDto(c: CategoryRow) {
  return {
    id: c.id,
    name: c.name,
    type: c.type,
    icon: c.icon,
    color: c.color,
    isArchived: c.isArchived,
    sortOrder: c.sortOrder,
    createdAt: c.createdAt.toISOString(),
    updatedAt: c.updatedAt.toISOString(),
  };
}

export class CategoriesService {
  constructor(private readonly repo: CategoriesRepository) {}

  async list(userId: string, opts: { type?: 'income' | 'expense'; includeArchived?: boolean } = {}) {
    const rows = await this.repo.listByUser(userId, opts);
    return rows.map(toCategoryDto);
  }

  async findOwned(userId: string, id: string, executor?: Database): Promise<CategoryRow> {
    const row = await this.repo.findByIdAndUser(userId, id, executor);
    if (!row) throw AppError.notFound('Category');
    return row;
  }

  async create(userId: string, input: CreateCategoryInput) {
    const row = await this.repo.insert({
      userId,
      name: input.name,
      type: input.type,
      icon: input.icon ?? 'more_horiz',
      color: input.color ?? '#64748B',
    });
    return toCategoryDto(row);
  }

  async update(userId: string, id: string, input: UpdateCategoryInput) {
    await this.findOwned(userId, id);
    const row = await this.repo.update(userId, id, input);
    return toCategoryDto(row);
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    if (await this.repo.isUsedByTransactions(userId, id)) {
      throw AppError.conflict('CATEGORY_IN_USE', 'Category is in use by transactions; archive it instead');
    }
    await this.repo.softDelete(userId, id);
  }
}
