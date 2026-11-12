import { AppError } from '../../common/errors.js';
import type { DashboardRepository } from './dashboard.repository.js';

/** Formats a Date as YYYY-MM in the given IANA timezone. */
function currentMonthInTz(tz: string, now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(now);
  const year = parts.find((p) => p.type === 'year')!.value;
  const month = parts.find((p) => p.type === 'month')!.value;
  return `${year}-${month}`;
}

/** Formats a Date as YYYY-MM-DD in the given IANA timezone. */
function currentDateInTz(tz: string, now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const year = parts.find((p) => p.type === 'year')!.value;
  const month = parts.find((p) => p.type === 'month')!.value;
  const day = parts.find((p) => p.type === 'day')!.value;
  return `${year}-${month}-${day}`;
}

/** Shifts a YYYY-MM string by `deltaMonths` (e.g. -1 for previous month). */
function addMonths(ym: string, deltaMonths: number): string {
  const [y, m] = ym.split('-').map(Number);
  const d = new Date(Date.UTC(y!, m! - 1 + deltaMonths, 1));
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

/** Shifts a YYYY-MM-DD string by `deltaDays`. */
function addDays(ymd: string, deltaDays: number): string {
  const [y, m, d] = ymd.split('-').map(Number);
  const dt = new Date(Date.UTC(y!, m! - 1, d! + deltaDays));
  const year = dt.getUTCFullYear();
  const month = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const day = String(dt.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export class DashboardService {
  constructor(private readonly repo: DashboardRepository) {}

  private async requireUserSettings(userId: string) {
    const u = await this.repo.getUserSettings(userId);
    if (!u) throw AppError.unauthorized('INVALID_TOKEN', 'User not found');
    return u;
  }

  async getSummary(userId: string, requestedMonth?: string) {
    const { baseCurrency, timezone } = await this.requireUserSettings(userId);
    const month = requestedMonth ?? currentMonthInTz(timezone);
    const prevMonth = addMonths(month, -1);

    const accRows = await this.repo.listActiveAccountsForCurrency(userId, baseCurrency);

    let totalAssets = 0;
    let totalLiabilities = 0;
    for (const a of accRows) {
      if (!a.includeInNetWorth) continue;
      if (a.balance >= 0) totalAssets += a.balance;
      else totalLiabilities += -a.balance;
    }
    const netWorth = totalAssets - totalLiabilities;

    const [totals, allTime] = await Promise.all([
      this.repo.getMonthlyTotalsForRange(
        userId,
        baseCurrency,
        timezone,
        prevMonth,
        month,
      ),
      this.repo.getAllTimeTotals(userId, baseCurrency),
    ]);

    const byMonth = new Map<string, { income: number; expense: number }>();
    for (const r of totals) {
      byMonth.set(r.ym, { income: r.income, expense: r.expense });
    }

    const cur = byMonth.get(month) ?? { income: 0, expense: 0 };
    const prev = byMonth.get(prevMonth) ?? { income: 0, expense: 0 };
    const net = cur.income - cur.expense;
    const savingsRate =
      cur.income > 0 ? Math.max(0, Math.min(1, Number(((cur.income - cur.expense) / cur.income).toFixed(4)))) : null;

    let financialStatus: 'excellent' | 'good' | 'fair' | 'warning';
    if (netWorth < 0 || (cur.expense > cur.income && cur.expense > 0)) {
      financialStatus = netWorth >= 0 ? 'fair' : 'warning';
    } else if (savingsRate !== null && savingsRate >= 0.25 && netWorth >= 0) {
      financialStatus = 'excellent';
    } else if (net >= 0 && netWorth >= 0) {
      financialStatus = 'good';
    } else {
      financialStatus = 'fair';
    }

    return {
      month,
      currency: baseCurrency,
      netWorth,
      totalAssets,
      totalLiabilities,
      totalIncome: allTime.totalIncome,
      totalExpense: allTime.totalExpense,
      income: cur.income,
      expense: cur.expense,
      net,
      savingsRate,
      financialStatus,
      previousMonth: prev,
      accountCount: accRows.length,
    };
  }

  async getCashflow(userId: string, monthsCount = 6) {
    const { baseCurrency, timezone } = await this.requireUserSettings(userId);
    const currentMonth = currentMonthInTz(timezone);
    const monthsList: string[] = [];
    for (let i = monthsCount - 1; i >= 0; i--) {
      monthsList.push(addMonths(currentMonth, -i));
    }
    const oldestMonth = monthsList[0]!;

    const rows = await this.repo.getMonthlyTotalsForRange(
      userId,
      baseCurrency,
      timezone,
      oldestMonth,
      currentMonth,
    );

    const byMonth = new Map<string, { income: number; expense: number }>();
    for (const r of rows) {
      byMonth.set(r.ym, { income: r.income, expense: r.expense });
    }

    return monthsList.map((m) => {
      const entry = byMonth.get(m) ?? { income: 0, expense: 0 };
      return {
        month: m,
        income: entry.income,
        expense: entry.expense,
        net: entry.income - entry.expense,
      };
    });
  }

  async getDailyCashflow(userId: string, daysCount = 14) {
    const { baseCurrency, timezone } = await this.requireUserSettings(userId);
    const today = currentDateInTz(timezone);
    const dateList: string[] = [];
    for (let i = daysCount - 1; i >= 0; i--) {
      dateList.push(addDays(today, -i));
    }
    const oldestDate = dateList[0]!;

    const rows = await this.repo.getDailyTotalsForRange(
      userId,
      baseCurrency,
      timezone,
      oldestDate,
      today,
    );

    const byDate = new Map<string, { income: number; expense: number }>();
    for (const r of rows) {
      byDate.set(r.ymd, { income: r.income, expense: r.expense });
    }

    return dateList.map((d) => {
      const entry = byDate.get(d) ?? { income: 0, expense: 0 };
      return {
        date: d,
        income: entry.income,
        expense: entry.expense,
        net: entry.income - entry.expense,
      };
    });
  }

  async getYearlyCashflow(userId: string, yearsCount = 5) {
    const { baseCurrency, timezone } = await this.requireUserSettings(userId);
    const currentYear = Number(currentMonthInTz(timezone).split('-')[0]);
    const yearsList: string[] = [];
    for (let i = yearsCount - 1; i >= 0; i--) {
      yearsList.push(String(currentYear - i));
    }
    const oldestYear = yearsList[0]!;

    const rows = await this.repo.getYearlyTotalsForRange(
      userId,
      baseCurrency,
      timezone,
      oldestYear,
      String(currentYear),
    );

    const byYear = new Map<string, { income: number; expense: number }>();
    for (const r of rows) {
      byYear.set(r.yr, { income: r.income, expense: r.expense });
    }

    return yearsList.map((yr) => {
      const entry = byYear.get(yr) ?? { income: 0, expense: 0 };
      return {
        year: yr,
        income: entry.income,
        expense: entry.expense,
        net: entry.income - entry.expense,
      };
    });
  }

  async getAccountBalancesOverview(userId: string) {
    const { baseCurrency } = await this.requireUserSettings(userId);
    const accRows = await this.repo.listActiveAccountsForCurrency(userId, baseCurrency);

    let totalAssets = 0;
    let totalLiabilities = 0;
    let totalAbsolute = 0;
    for (const a of accRows) {
      totalAbsolute += Math.abs(a.balance);
      if (!a.includeInNetWorth) continue;
      if (a.balance >= 0) totalAssets += a.balance;
      else totalLiabilities += -a.balance;
    }
    const netWorth = totalAssets - totalLiabilities;

    return {
      currency: baseCurrency,
      totalAssets,
      totalLiabilities,
      netWorth,
      accounts: accRows.map((a) => ({
        id: a.id,
        name: a.name,
        type: a.type,
        institution: a.institution,
        color: a.color,
        icon: a.icon,
        balance: a.balance,
        includeInNetWorth: a.includeInNetWorth,
        sharePercent:
          totalAbsolute > 0 ? Number(((Math.abs(a.balance) / totalAbsolute) * 100).toFixed(2)) : 0,
      })),
    };
  }

  async getCategoryBreakdown(userId: string, opts: { type: 'income' | 'expense'; month?: string }) {
    const { baseCurrency, timezone } = await this.requireUserSettings(userId);
    const month = opts.month ?? currentMonthInTz(timezone);

    const rawRows = await this.repo.getCategoryAggregates(
      userId,
      baseCurrency,
      timezone,
      month,
      opts.type,
    );

    const total = rawRows.reduce((sum, r) => sum + r.amount, 0);
    const items = rawRows.map((r) => {
      const percentage = total > 0 ? Number(((r.amount / total) * 100).toFixed(2)) : 0;
      return {
        categoryId: r.categoryId,
        name: r.name,
        icon: r.icon,
        color: r.color,
        amount: r.amount,
        percentage,
        count: r.count,
      };
    });

    return {
      month,
      type: opts.type,
      total,
      items,
    };
  }

  async getNetWorthTrend(userId: string, days = 30) {
    const { baseCurrency, timezone } = await this.requireUserSettings(userId);
    const today = currentDateInTz(timezone);

    const allAccounts = await this.repo.listActiveAccountsForCurrency(userId, baseCurrency);
    const eligibleAccounts = allAccounts.filter((a) => a.includeInNetWorth);

    const currentNetWorth = eligibleAccounts.reduce((sum, a) => sum + a.balance, 0);
    const dateList: string[] = [];
    for (let i = days - 1; i >= 0; i--) {
      dateList.push(addDays(today, -i));
    }
    if (eligibleAccounts.length === 0) {
      return dateList.map((date) => ({ date, netWorth: 0 }));
    }

    const startDate = dateList[0]!;
    const dailyDeltas = await this.repo.getDailyNetWorthDeltasFromDate(
      userId,
      baseCurrency,
      timezone,
      startDate,
    );

    const deltaByDate = new Map<string, number>();
    let futureDeltaAfterToday = 0;
    for (const r of dailyDeltas) {
      if (r.ymd > today) {
        futureDeltaAfterToday += r.delta;
      } else {
        deltaByDate.set(r.ymd, r.delta);
      }
    }

    // Walk backwards from end-of-today net worth (excluding any future-dated transactions).
    const eodToday = currentNetWorth - futureDeltaAfterToday;
    const result: { date: string; netWorth: number }[] = new Array(dateList.length);
    let running = eodToday;
    for (let i = dateList.length - 1; i >= 0; i--) {
      const date = dateList[i]!;
      result[i] = { date, netWorth: running };
      running -= deltaByDate.get(date) ?? 0;
    }

    return result;
  }

  /**
   * Section 12 Cloud Hosting Optimization:
   * Returns real-time database storage usage against the 512 MB Free-Tier quota
   * and process memory statistics.
   */
  async getStorageUsage(userId: string) {
    const FREE_TIER_QUOTA_BYTES = 512 * 1024 * 1024; // 512 MB
    const stats = await this.repo.getDatabaseStorageStats(userId);
    const mem = process.memoryUsage();
    const usagePercent = Number(
      ((stats.databaseBytes / FREE_TIER_QUOTA_BYTES) * 100).toFixed(2),
    );

    return {
      databaseBytes: stats.databaseBytes,
      quotaBytes: FREE_TIER_QUOTA_BYTES,
      usagePercent,
      remainingBytes: Math.max(0, FREE_TIER_QUOTA_BYTES - stats.databaseBytes),
      rowCounts: {
        accounts: stats.accountsCount,
        categories: stats.categoriesCount,
        transactions: stats.transactionsCount,
        refreshTokens: stats.refreshTokensCount,
      },
      serverMemoryRssBytes: mem.rss,
      serverHeapUsedBytes: mem.heapUsed,
      policyStatus: {
        transactionImagesOnServer: 0 as const,
        backupFilesOnServer: 0 as const,
      },
    };
  }
}
