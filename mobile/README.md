# MONEVO Mobile & Web Client (Flutter)

Premium personal finance & wealth management client for **MONEVO** (Thai-first UI, single owner account, integer minor-unit satang accounting).

---

## 1. Prerequisites

- **Flutter SDK**: `>=3.27.0` (Dart `>=3.5.0 <4.0.0`)
- Running MONEVO Backend (`backend/`, default port `3000`)

---

## 2. Generate Native Platform Folders

Only Dart source (`lib/`, `test/`, `pubspec.yaml`, `analysis_options.yaml`) is checked into `mobile/`. Before running on a simulator, device, or browser, generate the platform directories from inside `mobile/`:

```bash
cd mobile
flutter create . --org com.monevo --project-name monevo --platforms=android,ios,web
```

> **Note:** `flutter create .` will preserve existing files in `lib/`, `test/`, and `pubspec.yaml`. If it creates a default `test/widget_test.dart` that references the counter template, delete `test/widget_test.dart`.

---

## 3. Required Native Platform Configuration

### Android (`local_auth` & Network)

1. **`MainActivity` must extend `FlutterFragmentActivity`** (required by `local_auth`):

   Edit `android/app/src/main/kotlin/com/monevo/monevo/MainActivity.kt`:
   ```kotlin
   package com.monevo.monevo

   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity: FlutterFragmentActivity()
   ```

2. **Permissions in `android/app/src/main/AndroidManifest.xml`**:

   Add the following permissions inside `<manifest>` (above `<application>`):
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.USE_BIOMETRIC" />
   <uses-permission android:name="android.permission.CAMERA" />
   <!-- Android 12 and below only (Android 13+ uses the system Photo Picker without storage permission) -->
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
   ```

   *(Optional for local HTTP development on Android 9+)* Add `android:usesCleartextTraffic="true"` on the `<application>` tag if connecting to a non-HTTPS local backend.

3. **Minimum SDK in `android/app/build.gradle` (or `build.gradle.kts`)**:

   Ensure `minSdk` is at least `23` (required by `flutter_secure_storage` v9 and `local_auth`):
   ```groovy
   defaultConfig {
       applicationId = "com.monevo.monevo"
       minSdk = 23
       targetSdk = flutter.targetSdkVersion
       versionCode = flutter.versionCode
       versionName = flutter.versionName
   }
   ```

### iOS (`local_auth` Face ID & Local Receipt/Slip Image Picker)

Add `NSFaceIDUsageDescription`, `NSPhotoLibraryUsageDescription`, and `NSCameraUsageDescription` inside `<dict>` in `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>MONEVO uses Face ID to securely unlock your financial data.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>MONEVO accesses your photo library so you can attach payment slips or receipts to transactions (stored privately on your device only).</string>
<key>NSCameraUsageDescription</key>
<string>MONEVO uses the camera so you can photograph receipts or payment slips for your transactions (stored privately on your device only).</string>
```

---

## 4. Install Dependencies, Analyze & Test

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

---

## 5. Running the App & Configuring `API_BASE_URL`

The client reads `API_BASE_URL` at compile/run time via `--dart-define=API_BASE_URL=...`:

- **Android Emulator (default)**: `http://10.0.2.2:3000/api/v1`
  ```bash
  flutter run
  ```
- **iOS Simulator / macOS / Web / Desktop**: `http://localhost:3000/api/v1`
  ```bash
  flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
  ```
- **Production / Remote Server**:
  ```bash
  flutter run --release --dart-define=API_BASE_URL=https://your-monevo-api.example.com/api/v1
  ```

> **Health Endpoint:** The app automatically derives the root health endpoint (`GET /health` without `/api/v1`) from `API_BASE_URL` and displays a friendly cold-start wakeup screen while waiting for free-tier servers (~30–60s) to spin up.

---

## 6. Architecture Overview

```text
lib/
  main.dart, app.dart
  l10n/
    app_strings.dart               # Hand-written TH/EN localization (no codegen)
  core/
    config/app_config.dart         # API_BASE_URL & health URL derivation
    theme/                         # Emerald & Gold Material 3 light/dark themes + tabular figures
    router/app_router.dart         # GoRouter with wakeup, setup, auth, and PIN lock redirects
    network/                       # Dio client, single-flight token refresh interceptor, ApiException
    storage/                       # SecureStorageService (tokens + PIN hash/salt) & PreferencesService
    security/                      # SHA-256 salted PIN hasher, LocalAuth wrapper, background auto-lock
    utils/                         # Integer-only satang MoneyUtils & Thai/Buddhist Era AppDateUtils
    widgets/                       # AmountText (with privacy blur), IconMapper (34 keys + fallback), cards, skeletons
  features/
    auth/                          # Cold-start wakeup, first-time owner setup/register, login
    lock/                          # 6-digit PIN setup & PIN/biometric lock screen
    dashboard/                     # Net worth hero card, monthly summary, 6M cashflow bar chart, category donut, 30/90/365D trend, recent 5 tx
    accounts/                      # Grouped accounts list, detail view, reconcile, archive, create/edit sheet
    transactions/                  # Infinite-scroll day-grouped list, search/filters, keypad bottom sheet
    categories/                    # Expense/Income category management with icon & color pickers
    settings/                      # Profile, password change, PIN/biometric lock, privacy mode, TH/EN, BE/CE, theme mode
```
