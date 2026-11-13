import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AppError } from '../src/common/errors.js';
import { buildApp } from '../src/app.js';
import { loadEnv } from '../src/config/env.js';
import type { Database } from '../src/db/client.js';
import { isTransientDbError, MIGRATIONS_FOLDER, runMigrationsWithRetry } from '../src/db/migrate.js';
import * as schema from '../src/db/schema.js';

describe('MONEVO REST API (v1) integration suite', () => {
  let pgClient: PGlite;
  let db: Database;
  let app: FastifyInstance;

  let accessToken = '';
  let refreshToken = '';
  let bankAccountId = '';
  let creditCardAccountId = '';
  let walletAccountId = '';
  let salaryCategoryId = '';
  let foodCategoryId = '';
  let expenseTxId = '';

  beforeAll(async () => {
    pgClient = new PGlite();
    const pgliteDb = drizzle(pgClient, { schema });
    await migrate(pgliteDb, { migrationsFolder: MIGRATIONS_FOLDER });
    db = pgliteDb as unknown as Database;

    const env = loadEnv({
      NODE_ENV: 'test',
      LOG_LEVEL: 'silent',
      DATABASE_URL: 'postgres://test:test@localhost:5432/test',
      JWT_ACCESS_SECRET: 'test-access-secret-with-at-least-32-characters-12345',
      JWT_REFRESH_SECRET: 'test-refresh-secret-with-at-least-32-characters-67890',
      ENABLE_API_DOCS: 'true',
    });

    app = await buildApp({ env, db });
    await app.ready();
  });

  afterAll(async () => {
    await app?.close();
    await pgClient?.close();
  });

  it('GET /health and /api/v1/health return status ok without touching DB', async () => {
    const res1 = await app.inject({ method: 'GET', url: '/health' });
    expect(res1.statusCode).toBe(200);
    expect(res1.json()).toMatchObject({ status: 'ok', version: '1.0.0' });

    const res2 = await app.inject({ method: 'GET', url: '/api/v1/health' });
    expect(res2.statusCode).toBe(200);
  });

  it('serves OpenAPI specification at /docs/json', async () => {
    const res = await app.inject({ method: 'GET', url: '/docs/json' });
    expect(res.statusCode).toBe(200);
    const spec = res.json();
    expect(spec.openapi).toMatch(/^3\./);
    expect(spec.info.title).toContain('MONEVO');
  });

  it('completes owner registration, seeds default Thai categories, and closes registration afterwards', async () => {
    const statusBefore = await app.inject({ method: 'GET', url: '/api/v1/auth/status' });
    expect(statusBefore.statusCode).toBe(200);
    expect(statusBefore.json().data.registrationOpen).toBe(true);

    const reg = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: 'Owner@Example.com',
        password: 'SuperSecretPassword!123',
        displayName: 'เจ้าของบัญชี',
      },
    });
    expect(reg.statusCode).toBe(201);
    const body = reg.json().data;
    expect(body.user.email).toBe('owner@example.com');
    expect(body.user.baseCurrency).toBe('THB');
    expect(body.tokens.accessToken).toBeTypeOf('string');
    expect(body.tokens.refreshToken).toBeTypeOf('string');

    accessToken = body.tokens.accessToken;
    refreshToken = body.tokens.refreshToken;

    const statusAfter = await app.inject({ method: 'GET', url: '/api/v1/auth/status' });
    expect(statusAfter.json().data.registrationOpen).toBe(false);

    const secondReg = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: 'intruder@example.com',
        password: 'AnotherPassword!123',
        displayName: 'Intruder',
      },
    });
    expect(secondReg.statusCode).toBe(403);
    expect(secondReg.json().error.code).toBe('REGISTRATION_CLOSED');
  });

  it('rotates refresh tokens and revokes family on token reuse', async () => {
    const oldRefresh = refreshToken;
    const rotated = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/refresh',
      payload: { refreshToken: oldRefresh },
    });
    expect(rotated.statusCode).toBe(200);
    const newRefresh = rotated.json().data.tokens.refreshToken;
    expect(newRefresh).not.toBe(oldRefresh);

    // Reusing the old token must fail and revoke the family (including newRefresh).
    const reuse = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/refresh',
      payload: { refreshToken: oldRefresh },
    });
    expect(reuse.statusCode).toBe(401);
    expect(reuse.json().error.code).toBe('INVALID_TOKEN');

    const afterReuse = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/refresh',
      payload: { refreshToken: newRefresh },
    });
    expect(afterReuse.statusCode).toBe(401);

    // Log in again to get fresh tokens for subsequent tests.
    const login = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: 'owner@example.com', password: 'SuperSecretPassword!123' },
    });
    expect(login.statusCode).toBe(200);
    accessToken = login.json().data.tokens.accessToken;
    refreshToken = login.json().data.tokens.refreshToken;
  });

  it('lists seeded Thai categories and supports custom category lifecycle', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/categories',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(res.statusCode).toBe(200);
    const list = res.json().data as Array<{ id: string; name: string; type: string }>;
    expect(list.length).toBe(18);

    salaryCategoryId = list.find((c) => c.type === 'income' && c.name === 'เงินเดือน')!.id;
    foodCategoryId = list.find((c) => c.type === 'expense' && c.name === 'อาหาร')!.id;
    expect(salaryCategoryId).toBeTruthy();
    expect(foodCategoryId).toBeTruthy();

    // Verify all 10 required categories from Section 6.6 are present
    const names = new Set(list.map((c) => c.name));
    for (const requiredName of [
      'เงินเดือน',
      'รายได้เสริม',
      'อาหาร',
      'เดินทาง',
      'ที่พัก',
      'ค่าน้ำ',
      'ค่าไฟ',
      'ช้อปปิ้ง',
      'สุขภาพ',
      'ความบันเทิง',
    ]) {
      expect(names.has(requiredName)).toBe(true);
    }

    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/categories',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { name: 'กาแฟพิเศษ', type: 'expense', icon: 'local_cafe', color: '#8B5CF6' },
    });
    expect(created.statusCode).toBe(201);
    const customId = created.json().data.id;

    const del = await app.inject({
      method: 'DELETE',
      url: `/api/v1/categories/${customId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(del.statusCode).toBe(204);
  });

  it('creates accounts and tracks opening balances in satang (minor units)', async () => {
    const b1 = await app.inject({
      method: 'POST',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        name: 'กสิกรไทย ออมทรัพย์',
        type: 'bank',
        institution: 'KBank',
        accountNumberLast4: '4321',
        openingBalance: 10_000_00, // ฿10,000.00
        color: '#10B981',
      },
    });
    expect(b1.statusCode).toBe(201);
    bankAccountId = b1.json().data.id;
    expect(b1.json().data.balance).toBe(10_000_00);

    const b2 = await app.inject({
      method: 'POST',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        name: 'บัตรเครดิต SCB',
        type: 'credit_card',
        institution: 'SCB',
        openingBalance: -2_000_00, // -฿2,000.00 debt
      },
    });
    expect(b2.statusCode).toBe(201);
    creditCardAccountId = b2.json().data.id;

    const b3 = await app.inject({
      method: 'POST',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        name: 'กระเป๋าเงินสด',
        type: 'cash',
        openingBalance: 1_000_00, // ฿1,000.00
      },
    });
    expect(b3.statusCode).toBe(201);
    walletAccountId = b3.json().data.id;
  });

  it('records income, expense, and transfer transactions with atomic balance updates', async () => {
    // 1) Income +฿50,000.00 into bankAccount
    const inc = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'income',
        amount: 50_000_00,
        accountId: bankAccountId,
        categoryId: salaryCategoryId,
        occurredAt: '2026-11-05T09:00:00+07:00',
        payee: 'บริษัท MONEVO จำกัด',
        note: 'เงินเดือน พ.ย.',
      },
    });
    expect(inc.statusCode).toBe(201);

    // 2) Expense -฿150.75 from walletAccount
    const exp = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'expense',
        amount: 150_75,
        accountId: walletAccountId,
        categoryId: foodCategoryId,
        occurredAt: '2026-11-10T12:30:00+07:00',
        payee: 'ร้านอาหารไทย',
        note: 'มื้อเที่ยง',
      },
    });
    expect(exp.statusCode).toBe(201);
    expenseTxId = exp.json().data.id;

    // 3) Transfer ฿2,000.00 from bankAccount -> creditCardAccount (pays off card)
    const trf = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'transfer',
        amount: 2_000_00,
        accountId: bankAccountId,
        toAccountId: creditCardAccountId,
        occurredAt: '2026-11-11T15:00:00+07:00',
        note: 'ชำระบัตรเครดิต',
      },
    });
    expect(trf.statusCode).toBe(201);

    // Verify balances:
    // bank: 10,000 + 50,000 - 2,000 = 58,000.00 (58_000_00)
    // credit card: -2,000 + 2,000 = 0
    // wallet: 1,000 - 150.75 = 849.25 (849_25)
    const accList = await app.inject({
      method: 'GET',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const byId = new Map<string, number>(
      (accList.json().data as Array<{ id: string; balance: number }>).map((a) => [a.id, a.balance]),
    );
    expect(byId.get(bankAccountId)).toBe(58_000_00);
    expect(byId.get(creditCardAccountId)).toBe(0);
    expect(byId.get(walletAccountId)).toBe(849_25);
  });

  it('reverses and reapplies balances on PATCH and DELETE transaction, and reconciles accurately', async () => {
    // Update expense from 150.75 -> 250.00
    const patched = await app.inject({
      method: 'PATCH',
      url: `/api/v1/transactions/${expenseTxId}`,
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { amount: 250_00 },
    });
    expect(patched.statusCode).toBe(200);

    const walletAfterPatch = await app.inject({
      method: 'GET',
      url: `/api/v1/accounts/${walletAccountId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(walletAfterPatch.json().data.balance).toBe(750_00); // 1,000 - 250

    // Reconcile endpoint must agree with cached balance
    const reconciled = await app.inject({
      method: 'POST',
      url: `/api/v1/accounts/${walletAccountId}/reconcile`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(reconciled.statusCode).toBe(200);
    expect(reconciled.json().data.balance).toBe(750_00);

    // Prohibits deleting an account that has transactions
    const delAcc = await app.inject({
      method: 'DELETE',
      url: `/api/v1/accounts/${walletAccountId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(delAcc.statusCode).toBe(409);
    expect(delAcc.json().error.code).toBe('ACCOUNT_HAS_TRANSACTIONS');
  });

  it('supports cursor pagination and search on GET /transactions', async () => {
    const page1 = await app.inject({
      method: 'GET',
      url: '/api/v1/transactions?limit=2',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(page1.statusCode).toBe(200);
    expect(page1.json().data).toHaveLength(2);
    expect(page1.json().nextCursor).toBeTypeOf('string');

    const page2 = await app.inject({
      method: 'GET',
      url: `/api/v1/transactions?limit=2&cursor=${encodeURIComponent(page1.json().nextCursor)}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(page2.statusCode).toBe(200);
    expect(page2.json().data).toHaveLength(1);
    expect(page2.json().nextCursor).toBeNull();

    const search = await app.inject({
      method: 'GET',
      url: `/api/v1/transactions?q=${encodeURIComponent('มื้อเที่ยง')}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(search.statusCode).toBe(200);
    expect(search.json().data).toHaveLength(1);
    expect(search.json().data[0].id).toBe(expenseTxId);
  });

  it('computes dashboard summary, cashflow, category breakdown, and net-worth trend', async () => {
    const summary = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/summary?month=2026-11',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(summary.statusCode).toBe(200);
    const s = summary.json().data;
    expect(s.netWorth).toBe(58_750_00); // 58,000 + 0 + 750
    expect(s.totalIncome).toBe(50_000_00);
    expect(s.totalExpense).toBe(250_00);
    expect(s.income).toBe(50_000_00);
    expect(s.expense).toBe(250_00);
    expect(s.net).toBe(49_750_00);
    expect(s.savingsRate).toBeCloseTo(0.995, 3);
    expect(s.financialStatus).toBe('excellent');

    const cashflow = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/cashflow?months=6',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(cashflow.statusCode).toBe(200);
    expect(cashflow.json().data).toHaveLength(6);

    const dailyCashflow = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/daily-cashflow?days=14',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(dailyCashflow.statusCode).toBe(200);
    const dailyRows = dailyCashflow.json().data as Array<{ date: string; income: number; expense: number; net: number }>;
    expect(dailyRows).toHaveLength(14);

    const yearlyCashflow = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/yearly-cashflow?years=5',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(yearlyCashflow.statusCode).toBe(200);
    const yearlyRows = yearlyCashflow.json().data as Array<{ year: string; income: number; expense: number; net: number }>;
    expect(yearlyRows).toHaveLength(5);
    const year2026 = yearlyRows.find((r) => r.year === '2026');
    expect(year2026).toMatchObject({
      income: 50_000_00,
      expense: 250_00,
      net: 49_750_00,
    });

    const accountBalances = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/account-balances',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(accountBalances.statusCode).toBe(200);
    expect(accountBalances.json().data.netWorth).toBe(58_750_00);
    expect(accountBalances.json().data.accounts).toHaveLength(3);

    const cats = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/categories?type=expense&month=2026-11',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(cats.statusCode).toBe(200);
    expect(cats.json().data.total).toBe(250_00);
    expect(cats.json().data.items[0].percentage).toBe(100);

    const trend = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/net-worth-trend?days=14',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(trend.statusCode).toBe(200);
    const points = trend.json().data as Array<{ date: string; netWorth: number }>;
    expect(points).toHaveLength(14);
    expect(points[points.length - 1]!.netWorth).toBe(58_750_00);
  });

  it('enforces Critical Data Storage Policy (Section 3.2): blocks image, slip, receipt, and Base64 uploads to the server', async () => {
    // 1) Rejects data:image/...;base64 inside a text field
    const resDataUri = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'expense',
        amount: 50_00,
        accountId: walletAccountId,
        note: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      },
    });
    expect(resDataUri.statusCode).toBe(400);
    expect(resDataUri.json().error.code).toBe('IMAGE_UPLOAD_FORBIDDEN');

    // 2) Rejects prohibited field names such as slip / receipt / image
    const resField = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'expense',
        amount: 50_00,
        accountId: walletAccountId,
        slip: 'https://example.com/slip.jpg',
      },
    });
    expect(resField.statusCode).toBe(400);
    expect(resField.json().error.code).toBe('IMAGE_UPLOAD_FORBIDDEN');

    // 3) Rejects multipart/form-data binary uploads
    const resMultipart = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'multipart/form-data; boundary=---monevo',
      },
      payload: '-----monevo--',
    });
    expect(resMultipart.statusCode).toBe(400);
    expect(resMultipart.json().error.code).toBe('IMAGE_UPLOAD_FORBIDDEN');

    // 4) Section 11: Rejects bank passwords, PINs, or full unmasked account numbers
    const resBankSecret = await app.inject({
      method: 'POST',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        name: 'SCB Main',
        type: 'bank',
        bankPassword: 'MyBankPassword123',
      },
    });
    expect(resBankSecret.statusCode).toBe(400);
    expect(resBankSecret.json().error.code).toBe('BANK_CREDENTIAL_FORBIDDEN');
  });

  it('verifies Section 5 Database Design: transaction_types, app_settings, and PostgreSQL NUMERIC money columns (zero floating-point)', async () => {
    // 1) transaction_types table is seeded and queryable via GET /api/v1/transactions/types
    const typesRes = await app.inject({
      method: 'GET',
      url: '/api/v1/transactions/types',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(typesRes.statusCode).toBe(200);
    const typesData = typesRes.json().data as Array<{ code: string; balanceDirection: number }>;
    expect(typesData.map((t) => t.code)).toEqual(['income', 'expense', 'transfer']);

    // 2) app_settings table is seeded for owner and supports GET & PATCH /api/v1/auth/settings
    const getSettingsRes = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/settings',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(getSettingsRes.statusCode).toBe(200);
    expect(getSettingsRes.json().data).toMatchObject({
      themeMode: 'system',
      language: 'th',
      useBuddhistEra: true,
      privacyMode: false,
      autoLockSeconds: 60,
    });

    const patchSettingsRes = await app.inject({
      method: 'PATCH',
      url: '/api/v1/auth/settings',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        themeMode: 'dark',
        privacyMode: true,
        autoLockSeconds: 300,
      },
    });
    expect(patchSettingsRes.statusCode).toBe(200);
    expect(patchSettingsRes.json().data).toMatchObject({
      themeMode: 'dark',
      language: 'th',
      privacyMode: true,
      autoLockSeconds: 300,
    });

    // 3) Verify PostgreSQL catalog: all monetary columns use NUMERIC and zero columns use REAL/FLOAT
    const moneyCols = await pgClient.query<{ table_name: string; column_name: string; data_type: string }>(`
      SELECT table_name, column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND (
          (table_name = 'accounts' AND column_name IN ('opening_balance', 'balance'))
          OR (table_name = 'transactions' AND column_name IN ('amount', 'to_amount'))
        )
      ORDER BY table_name, column_name
    `);
    expect(moneyCols.rows).toEqual([
      { table_name: 'accounts', column_name: 'balance', data_type: 'numeric' },
      { table_name: 'accounts', column_name: 'opening_balance', data_type: 'numeric' },
      { table_name: 'transactions', column_name: 'amount', data_type: 'numeric' },
      { table_name: 'transactions', column_name: 'to_amount', data_type: 'numeric' },
    ]);

    const floatCols = await pgClient.query<{ column_name: string }>(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND data_type IN ('real', 'double precision')
    `);
    expect(floatCols.rows).toHaveLength(0);

    // 4) Section 12: Verify real-time database & storage quota inspection endpoint
    const storageRes = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/storage-usage',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(storageRes.statusCode).toBe(200);
    const storageData = storageRes.json().data;
    expect(storageData.databaseBytes).toBeGreaterThan(0);
    expect(storageData.quotaBytes).toBe(512 * 1024 * 1024);
    expect(storageData.rowCounts.accounts).toBe(3);
    expect(storageData.policyStatus).toEqual({
      transactionImagesOnServer: 0,
      backupFilesOnServer: 0,
    });
  });

  it('verifies Section 14 QA: Money Transfer rules, non-double-counting in charts, and balance restoration on DELETE', async () => {
    // 1) Rejects transfer where source and destination account are identical
    const sameAccTransfer = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'transfer',
        amount: 500_00,
        accountId: bankAccountId,
        toAccountId: bankAccountId,
        occurredAt: '2026-11-12T10:00:00+07:00',
      },
    });
    expect(sameAccTransfer.statusCode).toBe(400);

    // 2) Create a new transfer of ฿1,500.00 from bankAccount -> walletAccount
    const transferRes = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'transfer',
        amount: 1_500_00,
        accountId: bankAccountId,
        toAccountId: walletAccountId,
        occurredAt: '2026-11-12T11:00:00+07:00',
        note: 'เติมเงินสดเข้ากระเป๋า',
      },
    });
    expect(transferRes.statusCode).toBe(201);
    const tempTransferId = transferRes.json().data.id;

    // 3) Verify transfer updated both accounts atomically, while totalIncome & totalExpense remain unchanged (never double-counted!)
    const summaryDuringTransfer = await app.inject({
      method: 'GET',
      url: '/api/v1/dashboard/summary?month=2026-11',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(summaryDuringTransfer.statusCode).toBe(200);
    expect(summaryDuringTransfer.json().data.totalIncome).toBe(50_000_00);
    expect(summaryDuringTransfer.json().data.totalExpense).toBe(250_00);
    expect(summaryDuringTransfer.json().data.netWorth).toBe(58_750_00); // Net worth invariant under internal transfer

    // 4) Delete the transfer and verify both source & destination balances return to exact prior values
    const delTransfer = await app.inject({
      method: 'DELETE',
      url: `/api/v1/transactions/${tempTransferId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(delTransfer.statusCode).toBe(204);

    const accListAfter = await app.inject({
      method: 'GET',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const byId = new Map<string, number>(
      (accListAfter.json().data as Array<{ id: string; balance: number }>).map((a) => [a.id, a.balance]),
    );
    expect(byId.get(bankAccountId)).toBe(58_000_00);
    expect(byId.get(walletAccountId)).toBe(750_00);
  });

  it('verifies Section 14 QA: Security, API authorization, and SQL Injection protection', async () => {
    // 1) Blocks unauthenticated access to protected endpoints
    for (const url of [
      '/api/v1/accounts',
      '/api/v1/categories',
      '/api/v1/transactions',
      '/api/v1/dashboard/summary',
      '/api/v1/dashboard/storage-usage',
    ]) {
      const unauth = await app.inject({ method: 'GET', url });
      expect(unauth.statusCode).toBe(401);
    }

    // 2) Safely handles SQL injection payloads in search query and text fields via parameterized queries
    const sqliPayload = "'; DROP TABLE transactions; --";
    const sqliSearch = await app.inject({
      method: 'GET',
      url: `/api/v1/transactions?q=${encodeURIComponent(sqliPayload)}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(sqliSearch.statusCode).toBe(200);
    expect(sqliSearch.json().data).toEqual([]);

    // Verify transactions table is completely intact after SQLi attempt
    const txCheck = await app.inject({
      method: 'GET',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(txCheck.statusCode).toBe(200);
    expect(txCheck.json().data.length).toBeGreaterThanOrEqual(3);
  });

  it('successfully deletes an expense transaction and reverses account balance', async () => {
    // 1) Create account
    const acc = await app.inject({
      method: 'POST',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { name: 'Delete Expense Account', type: 'cash', openingBalance: 100_00 },
    });
    expect(acc.statusCode).toBe(201);
    const accId = acc.json().data.id;

    // 2) Create expense transaction
    const tx = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { type: 'expense', amount: 52_00, accountId: accId, occurredAt: new Date().toISOString() },
    });
    expect(tx.statusCode).toBe(201);
    const txId = tx.json().data.id;

    // 3) Delete transaction (specifically passing Content-Type: application/json with empty body like Dio client)
    const del = await app.inject({
      method: 'DELETE',
      url: `/api/v1/transactions/${txId}`,
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
    });
    console.log('DEL EXPENSE STATUS:', del.statusCode, del.body);
    expect(del.statusCode).toBe(204);

    // 4) Verify account balance reversed back to 100_00
    const accAfter = await app.inject({
      method: 'GET',
      url: `/api/v1/accounts/${accId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(accAfter.json().data.balance).toBe(100_00);
  });

  it('supports cascade account deletion (soft-deleting account and its transactions)', async () => {
    // 1) Create a temporary account
    const accRes = await app.inject({
      method: 'POST',
      url: '/api/v1/accounts',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { name: 'Cascade Test Account', type: 'cash', openingBalance: 100_00 },
    });
    expect(accRes.statusCode).toBe(201);
    const accId = accRes.json().data.id;

    // 2) Add a transaction to this account
    const txRes = await app.inject({
      method: 'POST',
      url: '/api/v1/transactions',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: {
        type: 'expense',
        amount: 25_00,
        accountId: accId,
        occurredAt: new Date().toISOString(),
      },
    });
    expect(txRes.statusCode).toBe(201);
    const txId = txRes.json().data.id;

    // 3) Normal delete without cascade should fail with 409
    const blocked = await app.inject({
      method: 'DELETE',
      url: `/api/v1/accounts/${accId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(blocked.statusCode).toBe(409);
    expect(blocked.json().error.code).toBe('ACCOUNT_HAS_TRANSACTIONS');

    // 4) Delete with cascade=true should succeed with 204
    const cascadeDel = await app.inject({
      method: 'DELETE',
      url: `/api/v1/accounts/${accId}?cascade=true`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(cascadeDel.statusCode).toBe(204);

    // 5) Verify account is gone
    const accCheck = await app.inject({
      method: 'GET',
      url: `/api/v1/accounts/${accId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(accCheck.statusCode).toBe(404);

    // 6) Verify transaction is gone
    const txCheck = await app.inject({
      method: 'GET',
      url: `/api/v1/transactions/${txId}`,
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(txCheck.statusCode).toBe(404);
  });

  it('retries transient TLS/socket database resets during cold startup migrations', async () => {
    const tlsResetError = Object.assign(new Error('Failed query: CREATE SCHEMA IF NOT EXISTS "drizzle"'), {
      cause: Object.assign(
        new Error('Client network socket disconnected before secure TLS connection was established'),
        { code: 'ECONNRESET', host: 'monevo-db.db.hostless.cloud' },
      ),
    });
    const permanentError = new Error('syntax error at or near "BADSQL"');

    expect(isTransientDbError(tlsResetError)).toBe(true);
    expect(isTransientDbError(permanentError)).toBe(false);

    let attempts = 0;
    await runMigrationsWithRetry(db, {
      delaysMs: [1, 1, 1],
      run: async () => {
        attempts += 1;
        if (attempts < 3) {
          throw tlsResetError;
        }
      },
    });
    expect(attempts).toBe(3);

    await expect(
      runMigrationsWithRetry(db, {
        delaysMs: [1, 1],
        run: async () => {
          throw permanentError;
        },
      }),
    ).rejects.toThrow('syntax error');
  });

  it('keeps /health returning 200 while returning structured 503 with CORS when DB is warming up', async () => {
    const env = loadEnv({
      NODE_ENV: 'test',
      LOG_LEVEL: 'silent',
      DATABASE_URL: 'postgres://test:test@localhost:5432/test',
      JWT_ACCESS_SECRET: 'test-access-secret-with-at-least-32-characters-12345',
      JWT_REFRESH_SECRET: 'test-refresh-secret-with-at-least-32-characters-67890',
      ENABLE_API_DOCS: 'false',
    });

    const warmingApp = await buildApp({
      env,
      db,
      beforeApiRequest: async () => {
        throw AppError.serviceUnavailable('Database is waking up');
      },
    });
    await warmingApp.ready();

    try {
      const h1 = await warmingApp.inject({ method: 'GET', url: '/health' });
      expect(h1.statusCode).toBe(200);

      const h2 = await warmingApp.inject({ method: 'GET', url: '/api/v1/health' });
      expect(h2.statusCode).toBe(200);

      const apiRes = await warmingApp.inject({
        method: 'GET',
        url: '/api/v1/accounts',
        headers: { origin: 'http://127.0.0.1:4322' },
      });
      expect(apiRes.statusCode).toBe(503);
      expect(apiRes.headers['access-control-allow-origin']).toBe('http://127.0.0.1:4322');
      expect(apiRes.json().error.code).toBe('SERVICE_UNAVAILABLE');
    } finally {
      await warmingApp.close();
    }
  });
});

