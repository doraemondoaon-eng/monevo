import { z } from 'zod';
import { currencyCode, hexColor, iconKey, minorUnits, nullableText } from '../../common/schemas.js';

export const accountType = z.enum(['bank', 'cash', 'credit_card', 'e_wallet', 'investment', 'other']);

export const accountDto = z.object({
  id: z.string(),
  name: z.string(),
  type: accountType,
  institution: z.string().nullable(),
  accountNumberLast4: z.string().nullable(),
  currency: z.string(),
  openingBalance: z.number().int(),
  balance: z.number().int(),
  color: z.string(),
  icon: z.string(),
  includeInNetWorth: z.boolean(),
  isArchived: z.boolean(),
  sortOrder: z.number().int(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const createAccountBody = z.object({
  name: z.string().trim().min(1).max(80),
  type: accountType,
  institution: nullableText(80),
  accountNumberLast4: z
    .string()
    .regex(/^\d{4}$/, 'Must be exactly 4 digits')
    .nullish(),
  currency: currencyCode.optional(),
  openingBalance: minorUnits.optional(),
  color: hexColor.optional(),
  icon: iconKey.optional(),
  includeInNetWorth: z.boolean().optional(),
});

export const updateAccountBody = createAccountBody
  .omit({ currency: true })
  .partial()
  .extend({
    isArchived: z.boolean().optional(),
    sortOrder: z.number().int().min(0).max(10_000).optional(),
  });

export type CreateAccountInput = z.output<typeof createAccountBody>;
export type UpdateAccountInput = z.output<typeof updateAccountBody>;

