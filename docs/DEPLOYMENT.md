# คู่มือการ Deploy ระบบ MONEVO (Neon PostgreSQL + Render Docker + GitHub)

เอกสารนี้อธิบายขั้นตอนการนำระบบ MONEVO ขึ้นใช้งานบน Cloud แบบ Serverless / Managed PaaS (Hostless) โดยเริ่มต้นด้วย **Free Tier** พร้อมสรุปข้อจำกัดที่ต้องทราบก่อนใช้งานจริง

---

## 1. ตารางตรวจสอบข้อจำกัด Free Tier (สำคัญมาก)

| บริการ | โควตา Free Tier | ข้อจำกัดสำคัญ | วิธีที่ MONEVO ออกแบบมารองรับ |
|---|---|---|---|
| **Neon PostgreSQL** | • พื้นที่จัดเก็บ **1 GB / โปรเจกต์**<br>• Compute **100 CU-hours / เดือน**<br>• Network Egress **5 GB / เดือน** | • Compute จะ **Scale-to-Zero** หลังไม่มี query นาน 5 นาที (ปลุกใช้เวลา ~0.5–1 วินาที) | • ตั้ง `connectionTimeoutMillis: 15000` ใน Backend เพื่อรอจังหวะฐานข้อมูลตื่น<br>• Endpoint `GET /health` **ไม่คิวรีฐานข้อมูล** เพื่อไม่ให้ keep-alive ping กินโควตา 100 CU-hours ของ Neon |
| **Render Web Service (Docker)** | • **750 ชั่วโมง / เดือน** (เพียงพอสำหรับรัน 1 เซอร์วิส 24/7 ตลอดเดือนที่มี 744 ชม.) | • **หลับอัตโนมัติ (Spin-down)** หลังไม่มี HTTP request นาน **15 นาที**<br>• เมื่อหลับ การเปิดใช้งานครั้งแรกจะใช้เวลา Cold Start ประมาณ **45–60 วินาที**<br>• ไม่มี Pre-deploy command ในแพ็กเกจฟรี | • แอป Flutter มีหน้าจอ **"กำลังเชื่อมต่อเซิร์ฟเวอร์"** ที่ลองเรียก `/health` อัตโนมัติระหว่างรอเซิร์ฟเวอร์ตื่น<br>• ตั้งค่า `RUN_MIGRATIONS_ON_START=true` และมี GitHub Actions สำหรับรัน Migration อัตโนมัติ<br>• สามารถตั้ง Keep-Alive Ping ทุก 10 นาทีได้ (ดูหัวข้อที่ 5) |
| **Render PostgreSQL** | ฟรีเพียง 30 วันแรก | **ฐานข้อมูลถูกลบเมื่อครบ 30 วัน** | **ห้ามใช้** — ใช้ **Neon PostgreSQL** แทน |

---

## 2. ขั้นตอนที่ 1: สร้างฐานข้อมูล PostgreSQL บน Neon

1. สมัครและเข้าสู่ระบบที่ https://neon.tech
2. กด **New Project**
   - **Project name:** `monevo`
   - **Postgres version:** `17`
   - **Region:** เลือก `AWS Asia Pacific (Singapore)` เพื่อให้ใกล้ประเทศไทยที่สุด
3. หลังสร้างเสร็จ ให้คัดลอก **Connection string** (แนะนำให้เลือกแบบ **Pooled connection**):
   ```text
   postgresql://<user>:<password>@ep-xxxx-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
   ```
4. เก็บค่านี้ไว้ใส่ใน `DATABASE_URL` ของ Render และ GitHub Secrets (ห้ามใส่ลงในโค้ดหรือ commit เข้า Git เด็ดขาด)

---

## 3. ขั้นตอนที่ 2: นำโค้ดขึ้น GitHub

```powershell
cd c:\Users\dorae\OneDrive\Desktop\MONEVO
git init
git add .
git commit -m "chore: initial MONEVO monorepo (backend + mobile)"
git branch -M main
git remote add origin https://github.com/<your-username>/MONEVO.git
git push -u origin main
```

*(ทางเลือก)* หากต้องการให้ GitHub Actions รัน Database Migration ให้ทุกครั้งที่ push โค้ดขึ้น `main`:
- ไปที่ GitHub Repo → **Settings → Secrets and variables → Actions → New repository secret**
- ตั้งชื่อ `DATABASE_URL` และวาง Connection string จาก Neon

---

## 4. ขั้นตอนที่ 3: Deploy Backend บน Render (ผ่าน `render.yaml`)

1. เข้าสู่ระบบที่ https://dashboard.render.com
2. ไปที่เมนู **Blueprints → New Blueprint Instance**
3. เชื่อมต่อกับ GitHub Repository `MONEVO`
4. Render จะอ่านไฟล์ [`render.yaml`](../render.yaml) อัตโนมัติ และถามค่า Environment Variable ที่ต้องกรอก:
   - `DATABASE_URL`: วาง Connection string จาก Neon
   - ค่าความลับ `JWT_ACCESS_SECRET` และ `JWT_REFRESH_SECRET` จะถูกสร้างแบบสุ่มที่ปลอดภัยให้อัตโนมัติ (`generateValue: true`)
5. กด **Apply** รอ Render build Docker image จาก [`backend/Dockerfile`](../backend/Dockerfile) และเริ่มต้นเซอร์วิส
6. เมื่อสถานะเป็น **Live** ทดสอบเปิดในเบราว์เซอร์:
   ```text
   https://<your-service>.onrender.com/health
   ```
   จะได้ผลลัพธ์ `{"status":"ok","uptime":...,"version":"1.0.0"}`

---

## 5. การทำให้ระบบออนไลน์ตลอดเวลา (Keep-Alive / Always-On)

เพื่อให้สอดคล้องกับเป้าหมาย **"รองรับการทำงานออนไลน์ตลอดเวลา"**:

### ตัวเลือก A: ใช้ Free Tier ร่วมกับ Uptime Monitor (ฟรี ฿0)
1. สมัครใช้งานบริการตรวจสอบสถานะเว็บไซต์ฟรี เช่น **UptimeRobot** หรือ **cron-job.org**
2. สร้าง HTTP(s) Monitor ชี้ไปที่:
   ```text
   https://<your-service>.onrender.com/health
   ```
3. ตั้งความถี่ทุก **10 นาที**
4. **ทำไมจึงไม่กระทบโควตา Neon?**
   เพราะ Endpoint `/health` ของ MONEVO ถูกออกแบบให้ตอบกลับจากหน่วยความจำของ Node.js ทันทีโดย **ไม่เปิดการเชื่อมต่อฐานข้อมูล** ทำให้ Render Web Service ไม่หลับ (ใช้โควตา ~720–744 ชม. จากที่มีให้ฟรี 750 ชม./เดือน) ในขณะที่ Neon PostgreSQL ยังคงพักตัวเองเมื่อคุณไม่ได้เปิดแอป

### ตัวเลือก B: อัปเกรด Render เป็นแผน Starter (เมื่อพร้อมใช้งานจริงจัง)
- เปลี่ยน Plan ของ `monevo-api` บน Render จาก `Free` เป็น `Starter` (~$7/เดือน) เซิร์ฟเวอร์จะทำงานตลอด 24 ชั่วโมงโดยไม่มี Spin-down และไม่ต้องแก้โค้ดใด ๆ

---

## 6. การเชื่อมต่อแอป Flutter เข้ากับ Backend ที่ Deploy แล้ว

เมื่อต้องการ build หรือรันแอป Flutter ให้ชี้ไปที่เซิร์ฟเวอร์จริงบน Render:

```powershell
cd mobile

# รันทดสอบบนเครื่อง/มือถือจริงโดยชี้ไปที่ Render
flutter run --dart-define=API_BASE_URL=https://<your-service>.onrender.com/api/v1

# Build APK สำหรับ Android
flutter build apk --release --dart-define=API_BASE_URL=https://<your-service>.onrender.com/api/v1

# Build สำหรับ Web (พร้อมขยายในอนาคต)
flutter build web --release --dart-define=API_BASE_URL=https://<your-service>.onrender.com/api/v1
```

