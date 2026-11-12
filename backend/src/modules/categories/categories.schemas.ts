import { z } from 'zod';
import { hexColor, iconKey } from '../../common/schemas.js';

export const categoryType = z.enum(['income', 'expense']);

export const categoryDto = z.object({
  id: z.string(),
  name: z.string(),
  type: categoryType,
  icon: z.string(),
  color: z.string(),
  isArchived: z.boolean(),
  sortOrder: z.number().int(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const createCategoryBody = z.object({
  name: z.string().trim().min(1).max(60),
  type: categoryType,
  icon: iconKey.optional(),
  color: hexColor.optional(),
});

export const updateCategoryBody = z.object({
  name: z.string().trim().min(1).max(60).optional(),
  icon: iconKey.optional(),
  color: hexColor.optional(),
  isArchived: z.boolean().optional(),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
});

export type CreateCategoryInput = z.output<typeof createCategoryBody>;
export type UpdateCategoryInput = z.output<typeof updateCategoryBody>;

