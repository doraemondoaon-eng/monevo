# MONEVO REST API Contract (v1)

This document is the **source of truth** shared by `backend/` and `mobile/`.
Interactive docs (generated from code) are served at `GET /docs` when the backend runs.

## Conventions

| Topic | Rule |
|---|---|
| Base URL | `https://<host>/api/v1` |
| Format | JSON, `camelCase` keys, UTF-8 |
| Auth | `Authorization: Bearer <accessToken>` on every endpoint except `/health`, `/auth/status`, `/auth/register`, `/auth/login`, `/auth/refresh` |
| **Money** | **Integer in minor units** (satang for THB). `150075` = ฿1,500.75. Never floats. `amount` on transactions is always **positive**; direction comes from `type`. |
| Currency | ISO-4217 code, e.g. `"THB"` |
| Timestamps | ISO-8601 with offset/UTC, e.g. `"2026-11-12T02:15:00.000Z"` |
| Months | `"YYYY-MM"`; dates `"YYYY-MM-DD"` — interpreted in the user's `timezone` (default `Asia/Bangkok`) |
| IDs | UUID strings |
| Single-resource responses | `{ "data": { ... } }` |
| List responses | `{ "data": [ ... ] }` (paginated lists add `"nextCursor": string \| null`) |
| No content | `204` with empty body |

### Errors

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Human readable message", "details": [ { "path": "amount", "message": "Must be > 0" } ] } }
```

| HTTP | `code` |
|---|---|
| 400 | `VALIDATION_ERROR`, `BAD_REQUEST`, `IMAGE_UPLOAD_FORBIDDEN` |
| 401 | `UNAUTHORIZED`, `INVALID_CREDENTIALS`, `TOKEN_EXPIRED`, `INVALID_TOKEN` |
| 403 | `REGISTRATION_CLOSED`, `FORBIDDEN` |
| 404 | `NOT_FOUND` |
| 409 | `CONFLICT`, `EMAIL_TAKEN`, `ACCOUNT_HAS_TRANSACTIONS`, `CATEGORY_IN_USE` |
| 429 | `RATE_LIMITED` |
| 500 | `INTERNAL_ERROR` |

When the access token expires the API returns **401 `TOKEN_EXPIRED`** → client calls `/auth/refresh` once, then retries.

---

## Health

`GET /health` (no `/api/v1` prefix, no auth, does not touch DB) → `200 { "status": "ok", "uptime": 123.4, "version": "1.0.0" }`

---

## Auth

### Models

```ts
User   = { id, email, displayName, baseCurrency: "THB", timezone: "Asia/Bangkok", createdAt }
Tokens = { accessToken: string, refreshToken: string, accessTokenExpiresIn: number /* seconds */, refreshTokenExpiresAt: string }
```

| Method & Path | Body | Response |
|---|---|---|
| `GET /auth/status` | – | `200 { data: { registrationOpen: boolean } }` — `true` only while no owner account exists |
| `POST /auth/register` | `{ email, password (min 10 chars), displayName }` | `201 { data: { user: User, tokens: Tokens } }` · `403 REGISTRATION_CLOSED` |
| `POST /auth/login` | `{ email, password }` | `200 { data: { user, tokens } }` · `401 INVALID_CREDENTIALS` · rate limited |
| `POST /auth/refresh` | `{ refreshToken }` | `200 { data: { tokens } }` (refresh token is **rotated**; old one becomes invalid — reuse revokes all sessions) |
| `POST /auth/logout` | `{ refreshToken }` | `204` |
| `GET /auth/me` | – | `200 { data: User }` |
| `PATCH /auth/me` | `{ displayName?, timezone? }` | `200 { data: User }` |
| `POST /auth/change-password` | `{ currentPassword, newPassword }` | `204` (revokes all refresh tokens) |

On successful registration the server seeds default Thai categories.

---

## Accounts (bank / cash / card / wallet)

```ts
AccountType = "bank" | "cash" | "credit_card" | "e_wallet" | "investment" | "other"
Account = {
  id, name, type: AccountType,
  institution: string | null,        // e.g. "KBank", "SCB"
  accountNumberLast4: string | null, // exactly 4 digits
  currency: "THB",
  openingBalance: number,            // minor units, may be negative (credit card debt)
  balance: number,                   // minor units, server-computed
  color: string,                     // "#RRGGBB"
  icon: IconKey,
  includeInNetWorth: boolean,
  isArchived: boolean,
  sortOrder: number,
  createdAt, updatedAt
}
```

| Method & Path | Body / Query | Response |
|---|---|---|
| `GET /accounts` | `?includeArchived=true\|false` (default false) | `200 { data: Account[] }` ordered by `sortOrder, createdAt` |
| `POST /accounts` | `{ name, type, institution?, accountNumberLast4?, currency?="THB", openingBalance?=0, color?, icon?, includeInNetWorth?=true }` | `201 { data: Account }` |
| `GET /accounts/:id` | – | `200 { data: Account }` |
| `PATCH /accounts/:id` | any create field + `isArchived?`, `sortOrder?` (`currency` immutable) | `200 { data: Account }` |
| `DELETE /accounts/:id` | – | `204` · `409 ACCOUNT_HAS_TRANSACTIONS` (archive instead) |
| `POST /accounts/:id/reconcile` | – | `200 { data: Account }` (recomputes `balance` from ledger) |

---

## Categories

```ts
Category = { id, name, type: "income" | "expense", icon: IconKey, color: "#RRGGBB", isArchived: boolean, sortOrder: number, createdAt, updatedAt }
```

| Method & Path | Body / Query | Response |
|---|---|---|
| `GET /categories` | `?type=income\|expense&includeArchived=false` | `200 { data: Category[] }` |
| `POST /categories` | `{ name, type, icon?, color? }` | `201 { data: Category }` |
| `PATCH /categories/:id` | `{ name?, icon?, color?, isArchived?, sortOrder? }` (`type` immutable) | `200 { data: Category }` |
| `DELETE /categories/:id` | – | `204` · `409 CATEGORY_IN_USE` (archive instead) |

---

## Transactions

A **transfer** is one record moving `amount` from `accountId` to `toAccountId` (both accounts must share a currency).

```ts
TransactionType = "income" | "expense" | "transfer"
Transaction = {
  id, type: TransactionType,
  amount: number,               // > 0, minor units
  currency: "THB",
  accountId: string,            // source account (for transfer: from)
  toAccountId: string | null,   // transfer only
  categoryId: string | null,    // income/expense only; must match type
  occurredAt: string,           // ISO timestamp
  payee: string | null,         // max 120
  note: string | null,          // max 500
  createdAt, updatedAt
}
```

| Method & Path | Body / Query | Response |
|---|---|---|
| `GET /transactions` | `?from=ISO&to=ISO&type=&accountId=&categoryId=&q=&limit=1..100 (default 30)&cursor=` | `200 { data: Transaction[], nextCursor: string \| null }` ordered `occurredAt desc, id desc`. `accountId` matches `accountId` **or** `toAccountId`. `q` searches payee + note (case-insensitive). `to` is exclusive. |
| `POST /transactions` | `{ type, amount, accountId, toAccountId?, categoryId?, occurredAt? (default now), payee?, note? }` | `201 { data: Transaction }` |
| `GET /transactions/:id` | – | `200 { data: Transaction }` |
| `PATCH /transactions/:id` | any create field (`type` change allowed; same validation) | `200 { data: Transaction }` |
| `DELETE /transactions/:id` | – | `204` |

Balance effects (applied atomically): income `+amount` on account; expense `−amount`; transfer `−amount` on `accountId`, `+amount` on `toAccountId`.

---

## Dashboard / Analytics

All sums only include non-archived accounts whose currency equals the user's `baseCurrency`, and accounts with `includeInNetWorth=true` for net-worth figures.

| Method & Path | Query | Response `data` |
|---|---|---|
| `GET /dashboard/summary` | `?month=YYYY-MM` (default current) | `{ month, currency, netWorth, totalAssets, totalLiabilities, income, expense, net, savingsRate: number \| null /* 0..1, null when income = 0 */, previousMonth: { income, expense }, accountCount }` |
| `GET /dashboard/cashflow` | `?months=1..24` (default 6) | `[{ month: "YYYY-MM", income, expense, net }]` oldest → newest, zero-filled |
| `GET /dashboard/categories` | `?type=expense\|income (default expense)&month=YYYY-MM` | `{ month, type, total, items: [{ categoryId: string \| null, name: string \| null, icon: IconKey \| null, color: string \| null, amount, percentage /* 0..100 */, count }] }` sorted by amount desc |
| `GET /dashboard/net-worth-trend` | `?days=7..365` (default 30) | `[{ date: "YYYY-MM-DD", netWorth }]` oldest → newest, one point per day (end-of-day value) |

---

## Icon keys (`IconKey`)

The backend stores icons as plain string keys; the app maps them to Material icons.

```
wallet, account_balance, payments, credit_card, savings, trending_up, phone_android,
restaurant, local_cafe, local_grocery_store, directions_car, local_gas_station, flight,
shopping_bag, home, bolt, water_drop, wifi, medical_services, fitness_center, movie,
sports_esports, school, shield, pets, child_care, card_giftcard, volunteer_activism,
work, star, store, percent, receipt_long, more_horiz
```

Unknown keys must fall back to `more_horiz` on the client.

