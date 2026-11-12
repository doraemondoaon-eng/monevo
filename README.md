# MONEVO — ระบบบริหารจัดการการเงินส่วนบุคคลระดับพรีเมียม

**MONEVO** คือแอปพลิเคชันบริหารจัดการการเงินส่วนบุคคลสำหรับบันทึกรายรับ–รายจ่าย, โอนเงินระหว่างบัญชี, จัดการบัญชีธนาคาร/บัตรเครดิต/กระเป๋าเงินสด, ติดตามความมั่งคั่งสุทธิ (Net Worth) และวิเคราะห์สถานะทางการเงินผ่าน Dashboard และกราฟสถิติ

ระบบถูกออกแบบมาให้ใช้งานโดยเจ้าของบัญชีเพียงคนเดียว (Single-Owner) แต่ใช้สถาปัตยกรรมแบบ Multi-User Ready (แยก `user_id` ในทุกตาราง) และแยก **Frontend** ออกจาก **Backend REST API** อย่างชัดเจน

---

## 1. Technology Stack

| ส่วนของระบบ | เทคโนโลยีหลัก | รายละเอียดเพิ่มเติม |
|---|---|---|
| **Frontend** | **Flutter · Dart** | รองรับ **iOS** และ **Android** และออกแบบแบบ Responsive / Web-ready เพื่อขยายไปยัง **Web** ในอนาคต (Riverpod, go_router, Dio, fl_chart, flutter_secure_storage, local_auth) |
| **Backend** | **Node.js · TypeScript · REST API** | Fastify 5, Zod 4 (Validation + OpenAPI 3), Argon2id, JWT (Access Token + Rotating Refresh Token with Reuse Detection), Rate Limit, Helmet, CORS |
| **Database** | **PostgreSQL** | Drizzle ORM + SQL Migrations, เก็บจำนวนเงินทั้งหมดในหน่วยย่อย (`BIGINT` สตางค์) เพื่อความแม่นยำ 100%, อัปเดตยอดคงเหลือแบบ Atomic Transaction |
| **Hosting** | **Cloud Hosting (Hostless / PaaS)** | **Render** (Docker Web Service) + **Neon** (Serverless PostgreSQL) พร้อมกลไกรองรับ Cold Start และ Keep-Alive |
| **Development** | **Git & GitHub · Docker · Migration · Env Vars** | Multi-stage `Dockerfile`, `docker-compose.yml`, `render.yaml`, GitHub Actions CI (`.github/workflows/ci.yml`), Vitest + PGlite Integration Tests |

---

## 2. โครงสร้างโปรเจกต์ (Monorepo)

```text
MONEVO/
├── backend/                  # Node.js + TypeScript REST API
│   ├── drizzle/              # SQL Database Migrations
│   ├── src/
│   │   ├── common/           # Error classes & shared Zod schemas
│   │   ├── config/           # Environment variable validation
│   │   ├── db/               # Drizzle PostgreSQL schema, client & migrator
│   │   ├── middleware/       # JWT auth & centralized error handler
│   │   ├── modules/          # auth · accounts · categories · transactions · dashboard
│   │   ├── security/         # Argon2id password hashing & JWT/refresh token service
│   │   ├── app.ts            # Fastify application factory
│   │   └── server.ts         # Production entrypoint
│   ├── test/                 # Integration tests (Vitest + PGlite PostgreSQL)
│   ├── Dockerfile            # Multi-stage production container
│   └── .env.example          # Template สำหรับตั้งค่าความลับ
├── mobile/                   # Flutter App (iOS / Android / Web-ready)
│   ├── lib/
│   │   ├── core/             # config · network · router · security · storage · theme · utils · widgets
│   │   ├── features/         # auth · lock · dashboard · accounts · transactions · categories · settings
│   │   ├── l10n/             # ภาษาไทย (ค่าเริ่มต้น) และภาษาอังกฤษ
│   │   ├── app.dart
│   │   └── main.dart
│   └── test/                 # Unit tests สำหรับการคำนวณเงินและโมเดล
├── docs/
│   ├── API.md                # สัญญาการเชื่อมต่อ REST API (v1)
│   └── DEPLOYMENT.md         # คู่มือการ Deploy บน Neon + Render + ข้อจำกัด Free Tier
├── docker-compose.yml        # PostgreSQL สำหรับพัฒนาในเครื่อง
├── render.yaml               # Render Infrastructure-as-Code Blueprint
└── .github/workflows/ci.yml  # GitHub Actions CI/CD
```

---

## 3. เริ่มต้นใช้งานอย่างรวดเร็ว (Quick Start)

### 3.1 การรันและทดสอบ Backend

> **ความต้องการ:** Node.js `>= 22` (ตรวจพบในเครื่องแล้ว `v24.15.0`)

```powershell
cd backend

# 1) คัดลอกไฟล์ตั้งค่า Environment Variables
Copy-Item .env.example .env

# 2) รันชุดทดสอบ Integration Test ทั้งระบบ (ใช้ PGlite ในตัว ไม่ต้องเปิด Docker)
npm test

# 3) ตรวจสอบ Type และ Lint
npm run typecheck
npm run lint

# 4) รันเซิร์ฟเวอร์โหมดพัฒนา (ต้องมี PostgreSQL จาก Docker หรือ Neon ใน DATABASE_URL)
npm run db:migrate
npm run dev
```

เมื่อเซิร์ฟเวอร์รันแล้ว:
- **Health Check:** `http://localhost:3000/health`
- **Swagger / OpenAPI UI:** `http://localhost:3000/docs`

### 3.2 การเริ่มต้นและรันแอป Flutter (`mobile/`)

> **ความต้องการ:** ติดตั้ง [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile) รุ่นเสถียร (`>= 3.27`)

```powershell
cd mobile

# 1) สร้างโฟลเดอร์แพลตฟอร์ม (android, ios, web) ครั้งแรกหลังติดตั้ง Flutter
flutter create . --org com.monevo --project-name monevo --platforms=android,ios,web

# 2) ติดตั้งแพ็กเกจและตรวจสอบโค้ด
flutter pub get
flutter analyze
flutter test

# 3) รันแอป (ตัวอย่างสำหรับ Android Emulator ที่ชี้มายัง Backend บนเครื่อง)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

ดูรายละเอียดการตั้งค่า `local_auth` (Face ID / ลายนิ้วมือ) สำหรับ Android และ iOS ได้ที่ [`mobile/README.md`](./mobile/README.md)

---

## 4. เอกสารสำคัญ

- **[System Architecture (`docs/ARCHITECTURE.md`)](./docs/ARCHITECTURE.md)** — สถาปัตยกรรม 3 ส่วนหลัก, ลำดับการไหลของข้อมูล, การแยกชั้น Business Logic ออกจาก UI และ Database, และการย้าย Hosting โดยไม่ต้องแก้โค้ด
- **[REST API Contract (`docs/API.md`)](./docs/API.md)** — รายละเอียด Endpoint, โครงสร้าง JSON, รหัสข้อผิดพลาด และกฎการคำนวณเงิน
- **[Deployment & Free Tier Guide (`docs/DEPLOYMENT.md`)](./docs/DEPLOYMENT.md)** — การตรวจสอบข้อจำกัด Free Tier ของ Render และ Neon, วิธีตั้งค่า Environment Variables และการตั้ง Keep-Alive ให้ระบบออนไลน์ตลอดเวลา

