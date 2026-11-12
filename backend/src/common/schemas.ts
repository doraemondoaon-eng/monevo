import { z } from 'zod';

export const ICON_KEYS = [
  'wallet', 'account_balance', 'payments', 'credit_card', 'savings', 'trending_up', 'phone_android',
  'restaurant', 'local_cafe', 'local_grocery_store', 'directions_car', 'local_gas_station', 'flight',
  'shopping_bag', 'home', 'bolt', 'water_drop', 'wifi', 'medical_services', 'fitness_center', 'movie',
  'sports_esports', 'school', 'shield', 'pets', 'child_care', 'card_giftcard', 'volunteer_activism',
  'work', 'star', 'store', 'percent', 'receipt_long', 'more_horiz',
] as const;

export const iconKey = z.enum(ICON_KEYS);
export const hexColor = z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Must be a #RRGGBB color');
export const currencyCode = z.string().regex(/^[A-Z]{3}$/, 'Must be an ISO-4217 code').default('THB');
export const uuidParam = z.object({ id: z.string().uuid() });

/** Integer minor units. Bounded to keep well inside JS safe-integer range. */
export const MAX_AMOUNT = 1_000_000_000_000_00; // 1 trillion in major units
export const minorUnits = z.number().int().min(-MAX_AMOUNT).max(MAX_AMOUNT);
export const positiveMinorUnits = z.number().int().positive().max(MAX_AMOUNT);

export const booleanQuery = z
  .enum(['true', 'false'])
  .transform((v) => v === 'true')
  .optional();

export const monthString = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'Must be YYYY-MM');

export const errorResponse = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.array(z.object({ path: z.string(), message: z.string() })).optional(),
  }),
});

export const dataEnvelope = <T extends z.ZodTypeAny>(schema: T) => z.object({ data: schema });

/** Trim strings and convert empty → null for optional text fields. */
export const nullableText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .nullish()
    .transform((v) => (v === undefined ? undefined : v === null || v === '' ? null : v));

