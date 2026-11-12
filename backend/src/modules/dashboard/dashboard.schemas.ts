import { z } from 'zod';
import { monthString } from '../../common/schemas.js';

export const financialStatusEnum = z.enum(['excellent', 'good', 'fair', 'warning']);

export const summaryDto = z.object({
  month: z.string(),
  currency: z.string(),
  netWorth: z.number().int(),
  totalAssets: z.number().int(),
  totalLiabilities: z.number().int(),
  totalIncome: z.number().int(),
  totalExpense: z.number().int(),
  income: z.number().int(),
  expense: z.number().int(),
  net: z.number().int(),
  savingsRate: z.number().nullable(),
  financialStatus: financialStatusEnum,
  previousMonth: z.object({
    income: z.number().int(),
    expense: z.number().int(),
  }),
  accountCount: z.number().int(),
});

export const cashflowPointDto = z.object({
  month: z.string(),
  income: z.number().int(),
  expense: z.number().int(),
  net: z.number().int(),
});

export const dailyCashflowPointDto = z.object({
  date: z.string(),
  income: z.number().int(),
  expense: z.number().int(),
  net: z.number().int(),
});

export const yearlyCashflowPointDto = z.object({
  year: z.string(),
  income: z.number().int(),
  expense: z.number().int(),
  net: z.number().int(),
});

export const accountBalanceItemDto = z.object({
  id: z.string(),
  name: z.string(),
  type: z.string(),
  institution: z.string().nullable(),
  color: z.string(),
  icon: z.string(),
  balance: z.number().int(),
  includeInNetWorth: z.boolean(),
  sharePercent: z.number(),
});

export const accountBalancesOverviewDto = z.object({
  currency: z.string(),
  totalAssets: z.number().int(),
  totalLiabilities: z.number().int(),
  netWorth: z.number().int(),
  accounts: z.array(accountBalanceItemDto),
});

export const categoryBreakdownItemDto = z.object({
  categoryId: z.string().nullable(),
  name: z.string().nullable(),
  icon: z.string().nullable(),
  color: z.string().nullable(),
  amount: z.number().int(),
  percentage: z.number(),
  count: z.number().int(),
});

export const categoryBreakdownDto = z.object({
  month: z.string(),
  type: z.enum(['income', 'expense']),
  total: z.number().int(),
  items: z.array(categoryBreakdownItemDto),
});

export const netWorthPointDto = z.object({
  date: z.string(),
  netWorth: z.number().int(),
});

export const summaryQuery = z.object({
  month: monthString.optional(),
});

export const cashflowQuery = z.object({
  months: z.coerce.number().int().min(1).max(24).default(6),
});

export const dailyCashflowQuery = z.object({
  days: z.coerce.number().int().min(1).max(90).default(14),
});

export const yearlyCashflowQuery = z.object({
  years: z.coerce.number().int().min(1).max(10).default(5),
});

export const categoriesQuery = z.object({
  type: z.enum(['income', 'expense']).default('expense'),
  month: monthString.optional(),
});

export const netWorthTrendQuery = z.object({
  days: z.coerce.number().int().min(7).max(365).default(30),
});

export const storageUsageDto = z.object({
  databaseBytes: z.number().int(),
  quotaBytes: z.number().int(),
  usagePercent: z.number(),
  remainingBytes: z.number().int(),
  rowCounts: z.object({
    accounts: z.number().int(),
    categories: z.number().int(),
    transactions: z.number().int(),
    refreshTokens: z.number().int(),
  }),
  serverMemoryRssBytes: z.number().int(),
  serverHeapUsedBytes: z.number().int(),
  policyStatus: z.object({
    transactionImagesOnServer: z.literal(0),
    backupFilesOnServer: z.literal(0),
  }),
});

