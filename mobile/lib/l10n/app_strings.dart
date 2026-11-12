import 'package:flutter/widgets.dart';

enum AppLanguage {
  th('th', 'ไทย'),
  en('en', 'English');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    if (code == 'en') {
      return AppLanguage.en;
    }
    return AppLanguage.th;
  }
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isThai => language == AppLanguage.th;

  static AppStrings of(BuildContext context) {
    final InheritedAppStrings? inherited =
        context.dependOnInheritedWidgetOfExactType<InheritedAppStrings>();
    return inherited?.strings ?? const AppStrings(AppLanguage.th);
  }

  String tr(String th, String en) => isThai ? th : en;

  // App & Navigation
  String get appName => 'MONEVO';
  String get appTagline => tr(
        'บริหารการเงินส่วนบุคคลอย่างเหนือระดับ',
        'Premium Personal Finance & Wealth Tracker',
      );
  String get navDashboard => tr('ภาพรวม', 'Dashboard');
  String get navTransactions => tr('รายการ', 'Transactions');
  String get navAccounts => tr('บัญชี', 'Accounts');
  String get navSettings => tr('ตั้งค่า', 'Settings');
  String get addTransaction => tr('จดรายการ', 'Add Entry');

  // Common actions
  String get save => tr('บันทึก', 'Save');
  String get cancel => tr('ยกเลิก', 'Cancel');
  String get delete => tr('ลบ', 'Delete');
  String get edit => tr('แก้ไข', 'Edit');
  String get archive => tr('เก็บเข้าคลัง', 'Archive');
  String get unarchive => tr('นำออกจากคลัง', 'Unarchive');
  String get confirm => tr('ยืนยัน', 'Confirm');
  String get retry => tr('ลองอีกครั้ง', 'Retry');
  String get close => tr('ปิด', 'Close');
  String get all => tr('ทั้งหมด', 'All');
  String get clear => tr('ล้างค่า', 'Clear');
  String get search => tr('ค้นหาผู้รับเงิน หรือบันทึกช่วยจำ...', 'Search payee or note...');
  String get loading => tr('กำลังโหลด...', 'Loading...');
  String get noData => tr('ไม่มีข้อมูล', 'No data available');
  String get viewAll => tr('ดูทั้งหมด', 'View All');
  String get today => tr('วันนี้', 'Today');
  String get yesterday => tr('เมื่อวาน', 'Yesterday');

  // Server Wakeup / Cold Start
  String get serverWakingTitle => tr(
        'กำลังเชื่อมต่อเซิร์ฟเวอร์ MONEVO...',
        'Connecting to MONEVO Server...',
      );
  String get serverWakingSubtitle => tr(
        'เซิร์ฟเวอร์อาจใช้เวลาตื่นจากโหมดประหยัดพลังงานประมาณ 30–60 วินาที กรุณารอสักครู่',
        'The server may take 30–60 seconds to wake up from cold start. Please wait a moment.',
      );
  String elapsedSeconds(int seconds) =>
      tr('เวลาที่รอ: $seconds วินาที', 'Elapsed: ${seconds}s');
  String retryAttempt(int attempt) =>
      tr('กำลังลองเชื่อมต่อครั้งที่ $attempt', 'Connection attempt #$attempt');

  // Auth & Setup
  String get setupOwnerTitle =>
      tr('ตั้งค่าบัญชีเจ้าของ MONEVO', 'Set Up Owner Account');
  String get setupOwnerSubtitle => tr(
        'ยินดีต้อนรับสู่ MONEVO สร้างบัญชีเจ้าของระบบ (สร้างได้เพียงบัญชีเดียว และจะพร้อมหมวดหมู่ภาษาไทยเริ่มต้น)',
        'Welcome to MONEVO. Create the single owner account (seeds default Thai categories automatically).',
      );
  String get loginTitle => tr('เข้าสู่ระบบ MONEVO', 'Sign In to MONEVO');
  String get loginSubtitle => tr(
        'เข้าถึงข้อมูลการเงินและทรัพย์สินส่วนบุคคลของคุณ',
        'Access your personal financial command center',
      );
  String get displayNameLabel => tr('ชื่อที่แสดง', 'Display Name');
  String get emailLabel => tr('อีเมล', 'Email');
  String get passwordLabel => tr('รหัสผ่าน', 'Password');
  String get passwordHintMin10 =>
      tr('อย่างน้อย 10 ตัวอักษร', 'Minimum 10 characters');
  String get confirmPasswordLabel => tr('ยืนยันรหัสผ่าน', 'Confirm Password');
  String get createOwnerButton =>
      tr('สร้างบัญชีและเริ่มต้นใช้งาน', 'Create Owner Account');
  String get signInButton => tr('เข้าสู่ระบบ', 'Sign In');
  String get logoutButton => tr('ออกจากระบบ', 'Sign Out');
  String get logoutConfirm => tr(
        'คุณต้องการออกจากระบบใช่หรือไม่?',
        'Are you sure you want to sign out?',
      );

  // Lock & Security
  String get appLockedTitle => tr('ยืนยันตัวตนเพื่อเข้าใช้งาน', 'Unlock MONEVO');
  String get enterPinPrompt =>
      tr('กรอกรหัส PIN 6 หลักของคุณ', 'Enter your 6-digit PIN');
  String get setupPinTitle => tr('ตั้งรหัส PIN 6 หลัก', 'Set 6-Digit PIN');
  String get confirmPinTitle =>
      tr('ยืนยันรหัส PIN อีกครั้ง', 'Confirm Your 6-Digit PIN');
  String get pinMismatchError =>
      tr('รหัส PIN ไม่ตรงกัน กรุณาลองใหม่', 'PIN codes do not match. Try again.');
  String get invalidPinError =>
      tr('รหัส PIN ไม่ถูกต้อง', 'Incorrect PIN code');
  String get unlockWithBiometrics =>
      tr('ปลดล็อกด้วยไบโอเมตริกซ์', 'Unlock with Biometrics');
  String get biometricPromptReason => tr(
        'ยืนยันตัวตนเพื่อเข้าถึงข้อมูลการเงินใน MONEVO',
        'Authenticate to unlock MONEVO',
      );

  // Dashboard
  String get netWorthTitle => tr('ความมั่งคั่งสุทธิ (Net Worth)', 'Total Net Worth');
  String get totalAssets => tr('สินทรัพย์รวม', 'Total Assets');
  String get totalLiabilities => tr('หนี้สินรวม', 'Total Liabilities');
  String get monthlyOverview => tr('สรุปประจำเดือน', 'Monthly Summary');
  String get income => tr('รายรับ', 'Income');
  String get expense => tr('รายจ่าย', 'Expense');
  String get transfer => tr('โอนเงิน', 'Transfer');
  String get netCashflow => tr('คงเหลือสุทธิ', 'Net Cashflow');
  String get savingsRate => tr('อัตราการออม', 'Savings Rate');
  String get cashflow6Months =>
      tr('กระแสเงินสดย้อนหลัง 6 เดือน', '6-Month Cashflow');
  String get categoryBreakdownTitle =>
      tr('สัดส่วนตามหมวดหมู่', 'Category Breakdown');
  String get netWorthTrendTitle =>
      tr('แนวโน้มความมั่งคั่งสุทธิ', 'Net Worth Trend');
  String get recentTransactionsTitle =>
      tr('รายการล่าสุด', 'Recent Transactions');
  String get vsPreviousMonth => tr('เทียบเดือนก่อน', 'vs prev month');

  // Accounts
  String get accountsTitle => tr('บัญชีทั้งหมด', 'Accounts');
  String get addAccount => tr('เพิ่มบัญชี', 'Add Account');
  String get editAccount => tr('แก้ไขบัญชี', 'Edit Account');
  String get accountName => tr('ชื่อบัญชี', 'Account Name');
  String get accountType => tr('ประเภทบัญชี', 'Account Type');
  String get institution => tr('สถาบันการเงิน / ธนาคาร', 'Institution / Bank');
  String get last4Digits =>
      tr('เลขท้าย 4 หลัก (ไม่บังคับ)', 'Last 4 Digits (Optional)');
  String get openingBalance =>
      tr('ยอดยกมาเริ่มต้น (บาท)', 'Opening Balance (THB)');
  String get currentBalance => tr('ยอดคงเหลือปัจจุบัน', 'Current Balance');
  String get includeInNetWorth =>
      tr('รวมในคำนวณความมั่งคั่งสุทธิ', 'Include in Net Worth');
  String get showArchived => tr('แสดงที่เก็บเข้าคลัง', 'Show Archived');
  String get reconcileAccount =>
      tr('กระทบยอดบัญชี (Reconcile)', 'Reconcile Balance');
  String get reconcileSuccess => tr(
        'คำนวณยอดคงเหลือจากรายการเดินบัญชีใหม่เรียบร้อยแล้ว',
        'Account balance reconciled with ledger',
      );

  // Transactions
  String get newTransaction => tr('บันทึกรายการใหม่', 'New Transaction');
  String get editTransaction => tr('แก้ไขรายการ', 'Edit Transaction');
  String get deleteTransactionConfirm =>
      tr('ยืนยันการลบรายการธุรกรรม?', 'Delete this transaction?');
  String get genericErrorMessage => tr(
        'เกิดข้อผิดพลาดในการโหลดข้อมูล กรุณาลองใหม่อีกครั้ง',
        'Something went wrong while loading data. Please try again.',
      );
  String get amount => tr('จำนวนเงิน', 'Amount');
  String get fromAccount => tr('จากบัญชี', 'From Account');
  String get fromAccountLabel => tr('จากบัญชีต้นทาง', 'From Account');
  String get toAccount => tr('ไปยังบัญชีปลายทาง', 'To Account');
  String get toAccountLabel => tr('ไปยังบัญชีปลายทาง', 'To Account');
  String get account => tr('บัญชี', 'Account');
  String get accountLabel => tr('บัญชี', 'Account');
  String get category => tr('หมวดหมู่', 'Category');
  String get categoryLabel => tr('หมวดหมู่', 'Category');
  String get occurredAt => tr('วันและเวลา', 'Date & Time');
  String get dateTimeLabel => tr('วันและเวลา', 'Date & Time');
  String get payee => tr('ผู้รับเงิน / ร้านค้า', 'Payee / Merchant');
  String get note => tr('บันทึกเพิ่มเติม', 'Note');
  String get noteLabel => tr('บันทึกเพิ่มเติม', 'Note');
  String get uncategorized => tr('ไม่ระบุหมวดหมู่', 'Uncategorized');

  // Categories
  String get categoriesTitle => tr('จัดการหมวดหมู่', 'Manage Categories');
  String get addCategory => tr('เพิ่มหมวดหมู่', 'New Category');
  String get editCategory => tr('แก้ไขหมวดหมู่', 'Edit Category');
  String get categoryName => tr('ชื่อหมวดหมู่', 'Category Name');
  String get selectIcon => tr('เลือกไอคอน', 'Select Icon');
  String get selectColor => tr('เลือกสี', 'Select Color');

  // Settings
  String get profileSection => tr('โปรไฟล์เจ้าของบัญชี', 'Owner Profile');
  String get securitySection => tr('ความปลอดภัย', 'Security & Privacy');
  String get preferencesSection => tr('การแสดงผลและภาษา', 'Display & Preferences');
  String get dataManagementSection => tr('การจัดการข้อมูล', 'Data Management');
  String get privacyModeLabel =>
      tr('โหมดซ่อนตัวเลขเงิน (Privacy Mode)', 'Privacy Mode (Hide Amounts)');
  String get biometricUnlockLabel =>
      tr('ปลดล็อกด้วยลายนิ้วมือ / Face ID', 'Biometric Unlock');
  String get pinLockLabel => tr('รหัส PIN ล็อกแอป', 'App PIN Lock');
  String get autoLockLabel => tr('ล็อกอัตโนมัติเมื่อพับหน้าจอ', 'Auto-Lock Timeout');
  String get changePasswordLabel => tr('เปลี่ยนรหัสผ่าน', 'Change Password');
  String get languageLabel => tr('ภาษา (Language)', 'Language');
  String get buddhistEraLabel =>
      tr('แสดงปี พ.ศ. (Buddhist Era)', 'Use Buddhist Era (BE +543)');
  String get themeModeLabel => tr('โหมดสีหน้าจอ', 'Theme Mode');
  String get themeSystem => tr('ตามระบบ', 'System');
  String get themeLight => tr('สว่าง', 'Light');
  String get themeDark => tr('มืด', 'Dark');
}

class InheritedAppStrings extends InheritedWidget {
  const InheritedAppStrings({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  @override
  bool updateShouldNotify(InheritedAppStrings oldWidget) {
    return oldWidget.strings.language != strings.language;
  }
}
