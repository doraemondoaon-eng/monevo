import { z } from 'zod';
import { nullableText, positiveMinorUnits } from '../../common/schemas.js';

export const transactionType = z.enum(['income', 'expense', 'transfer']);

export const transactionTypeInfoDto = z.object({
  code: transactionType,
  labelTh: z.string(),
  labelEn: z.string(),
  balanceDirection: z.number().int(),
  requiresCategory: z.boolean(),
  requiresDestinationAccount: z.boolean(),
  sortOrder: z.number().int(),
});

export const transactionDto = z.object({
  id: z.string(),
  type: transactionType,
  amount: z.number().int(),
  currency: z.string(),
  accountId: z.string(),
  toAccountId: z.string().nullable(),
  categoryId: z.string().nullable(),
  occurredAt: z.string(),
  payee: z.string().nullable(),
  note: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const listTransactionsQuery = z.object({
  from: z.string().datetime({ offset: true }).optional(),
  to: z.string().datetime({ offset: true }).optional(),
  type: transactionType.optional(),
  accountId: z.string().uuid().optional(),
  categoryId: z.string().uuid().optional(),
  q: z.string().trim().max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
  cursor: z.string().optional(),
});

export const createTransactionBody = z.object({
  type: transactionType,
  amount: positiveMinorUnits,
  accountId: z.string().uuid(),
  toAccountId: z.string().uuid().nullish(),
  categoryId: z.string().uuid().nullish(),
  occurredAt: z.string().datetime({ offset: true }).optional(),
  payee: nullableText(120),
  note: nullableText(500),
});

export const updateTransactionBody = createTransactionBody.partial();

export type ListTransactionsQuery = z.output<typeof listTransactionsQuery>;
export type CreateTransactionInput = z.output<typeof createTransactionBody>;
export type UpdateTransactionInput = z.output<typeof updateTransactionBody>;

