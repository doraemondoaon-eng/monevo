import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { dataEnvelope } from '../../common/schemas.js';
import {
  accountBalancesOverviewDto,
  cashflowPointDto,
  cashflowQuery,
  categoriesQuery,
  categoryBreakdownDto,
  dailyCashflowPointDto,
  dailyCashflowQuery,
  netWorthPointDto,
  netWorthTrendQuery,
  storageUsageDto,
  summaryDto,
  summaryQuery,
  yearlyCashflowPointDto,
  yearlyCashflowQuery,
} from './dashboard.schemas.js';
import type { DashboardService } from './dashboard.service.js';

export function registerDashboardRoutes(app: FastifyInstance, dashboard: DashboardService): void {
  const r = app.withTypeProvider<ZodTypeProvider>();

  r.get(
    '/dashboard/summary',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Monthly financial summary & net worth',
        querystring: summaryQuery,
        response: { 200: dataEnvelope(summaryDto) },
      },
    },
    async (req) => ({
      data: await dashboard.getSummary(req.userId, req.query.month),
    }),
  );

  r.get(
    '/dashboard/cashflow',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Monthly income vs expense cashflow series',
        querystring: cashflowQuery,
        response: { 200: dataEnvelope(z.array(cashflowPointDto)) },
      },
    },
    async (req) => ({
      data: await dashboard.getCashflow(req.userId, req.query.months),
    }),
  );

  r.get(
    '/dashboard/daily-cashflow',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Daily income vs expense cashflow series',
        querystring: dailyCashflowQuery,
        response: { 200: dataEnvelope(z.array(dailyCashflowPointDto)) },
      },
    },
    async (req) => ({
      data: await dashboard.getDailyCashflow(req.userId, req.query.days),
    }),
  );

  r.get(
    '/dashboard/yearly-cashflow',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Yearly income vs expense cashflow series',
        querystring: yearlyCashflowQuery,
        response: { 200: dataEnvelope(z.array(yearlyCashflowPointDto)) },
      },
    },
    async (req) => ({
      data: await dashboard.getYearlyCashflow(req.userId, req.query.years),
    }),
  );

  r.get(
    '/dashboard/account-balances',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Account Balance Overview across all active accounts',
        response: { 200: dataEnvelope(accountBalancesOverviewDto) },
      },
    },
    async (req) => ({
      data: await dashboard.getAccountBalancesOverview(req.userId),
    }),
  );

  r.get(
    '/dashboard/categories',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Category breakdown for a month',
        querystring: categoriesQuery,
        response: { 200: dataEnvelope(categoryBreakdownDto) },
      },
    },
    async (req) => ({
      data: await dashboard.getCategoryBreakdown(req.userId, {
        type: req.query.type,
        month: req.query.month,
      }),
    }),
  );

  r.get(
    '/dashboard/net-worth-trend',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Daily end-of-day net worth trend',
        querystring: netWorthTrendQuery,
        response: { 200: dataEnvelope(z.array(netWorthPointDto)) },
      },
    },
    async (req) => ({
      data: await dashboard.getNetWorthTrend(req.userId, req.query.days),
    }),
  );

  r.get(
    '/dashboard/storage-usage',
    {
      preHandler: [app.authenticate],
      schema: {
        tags: ['Dashboard'],
        summary: 'Inspect actual PostgreSQL database size & 512 MB free-tier quota usage (Section 12)',
        response: { 200: dataEnvelope(storageUsageDto) },
      },
    },
    async (req) => ({
      data: await dashboard.getStorageUsage(req.userId),
    }),
  );
}

