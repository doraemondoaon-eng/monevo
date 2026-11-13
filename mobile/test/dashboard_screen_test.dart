import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/security/app_lock_controller.dart';
import 'package:monevo/core/security/biometric_service.dart';
import 'package:monevo/core/storage/local_cache_service.dart';
import 'package:monevo/core/storage/preferences_service.dart';
import 'package:monevo/core/storage/secure_storage_service.dart';
import 'package:monevo/core/theme/app_theme.dart';
import 'package:monevo/features/accounts/data/accounts_api.dart';
import 'package:monevo/features/accounts/data/accounts_repository.dart';
import 'package:monevo/features/accounts/presentation/accounts_controller.dart';
import 'package:monevo/features/auth/data/auth_api.dart';
import 'package:monevo/features/auth/data/auth_repository.dart';
import 'package:monevo/features/auth/domain/auth_models.dart';
import 'package:monevo/features/auth/presentation/auth_controller.dart';
import 'package:monevo/features/categories/data/categories_api.dart';
import 'package:monevo/features/categories/data/categories_repository.dart';
import 'package:monevo/features/categories/presentation/categories_controller.dart';
import 'package:monevo/features/dashboard/data/dashboard_api.dart';
import 'package:monevo/features/dashboard/data/dashboard_repository.dart';
import 'package:monevo/features/dashboard/domain/dashboard_models.dart';
import 'package:monevo/features/dashboard/presentation/dashboard_controller.dart';
import 'package:monevo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:monevo/features/dashboard/presentation/dashboard_visuals.dart';
import 'package:monevo/features/settings/presentation/settings_controller.dart';
import 'package:monevo/features/transactions/data/transactions_api.dart';
import 'package:monevo/features/transactions/data/transactions_repository.dart';
import 'package:monevo/l10n/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopBiometricService implements BiometricService {
  @override
  Future<bool> authenticate({required String localizedReason}) async => false;

  @override
  Future<bool> isAvailable() async => false;
}

class _SeededAuthController extends AuthController {
  _SeededAuthController(User user)
    : super(
        AuthRepository(
          api: AuthApi(Dio()),
          secureStorage: InMemorySecureStorageService(),
        ),
        autoBootstrap: false,
      ) {
    state = AuthState(stage: AuthStage.authenticated, user: user);
  }
}

class _SeededSettingsController extends SettingsController {
  _SeededSettingsController() : super(PreferencesService()) {
    state = const AppSettingsState(
      themeMode: ThemeMode.light,
      language: AppLanguage.th,
      useBuddhistEra: true,
      loaded: true,
    );
  }

  @override
  Future<void> load() async {}
}

class _SeededAppLockController extends AppLockController {
  _SeededAppLockController()
    : super(
        secureStorage: InMemorySecureStorageService(),
        preferences: PreferencesService(),
        biometricService: _NoopBiometricService(),
      ) {
    state = const AppLockState(initialized: true);
  }

  @override
  Future<void> initialize() async {}
}

class _SeededAccountsController extends AccountsController {
  _SeededAccountsController()
    : super(
        AccountsRepository(api: AccountsApi(Dio()), cache: LocalCacheService()),
        isAuthenticated: false,
      ) {
    state = const AccountsState();
  }
}

class _SeededCategoriesController extends CategoriesController {
  _SeededCategoriesController()
    : super(
        CategoriesRepository(
          api: CategoriesApi(Dio()),
          cache: LocalCacheService(),
        ),
        isAuthenticated: false,
      ) {
    state = const CategoriesState();
  }
}

class _SeededDashboardController extends DashboardController {
  _SeededDashboardController(DashboardState initialState)
    : super(
        dashboardRepo: DashboardRepository(
          api: DashboardApi(Dio()),
          cache: LocalCacheService(),
        ),
        transactionsRepo: TransactionsRepository(
          api: TransactionsApi(Dio()),
          cache: LocalCacheService(),
        ),
        isAuthenticated: false,
      ) {
    state = initialState;
  }

  @override
  void setCashflowGranularity(CashflowGranularity granularity) {
    state = state.copyWith(cashflowGranularity: granularity);
  }

  @override
  Future<void> setDailyCashflowDays(int days) async {
    state = state.copyWith(dailyCashflowDays: days);
  }

  @override
  Future<void> setCashflowMonths(int months) async {
    state = state.copyWith(cashflowMonths: months);
  }

  @override
  Future<void> setYearlyCashflowYears(int years) async {
    state = state.copyWith(yearlyCashflowYears: years);
  }

  @override
  Future<void> setTrendDays(int days) async {
    state = state.copyWith(trendDays: days);
  }
}

void main() {
  final DateTime fixedNow = DateTime(2026, 11, 13, 15, 30);

  DashboardState buildRealisticState() {
    final List<DailyCashflowPoint> daily30 = List<DailyCashflowPoint>.generate(
      30,
      (int i) {
        final DateTime dt = DateTime(2026, 10, 15).add(Duration(days: i));
        final String m = dt.month.toString().padLeft(2, '0');
        final String d = dt.day.toString().padLeft(2, '0');
        return DailyCashflowPoint(
          date: '${dt.year}-$m-$d',
          income: i == 29 ? 10300 : 0,
          expense: i == 29 ? 41900 : (i % 5 == 0 ? 12000 : 0),
          net: 0,
        );
      },
    );

    final List<NetWorthPoint> nwPoints = List<NetWorthPoint>.generate(
      30,
      (int i) {
        final DateTime dt = DateTime(2026, 10, 15).add(Duration(days: i));
        final String m = dt.month.toString().padLeft(2, '0');
        final String d = dt.day.toString().padLeft(2, '0');
        return NetWorthPoint(
          date: '${dt.year}-$m-$d',
          netWorth: i >= 28 ? -3672100 : -3640600,
        );
      },
    );

    return DashboardState(
      selectedMonth: '2026-11',
      summary: const DashboardSummary(
        month: '2026-11',
        currency: 'THB',
        netWorth: -3672100,
        totalAssets: 1127900,
        totalLiabilities: 4800000,
        totalIncome: 10300,
        totalExpense: 41900,
        income: 10300,
        expense: 41900,
        net: -31600,
        savingsRate: 0.0,
        financialStatus: 'caution',
        previousMonth: PreviousMonthTotals(income: 0, expense: 0),
        accountCount: 3,
      ),
      cashflowMonths: 6,
      cashflow: const <CashflowPoint>[
        CashflowPoint(month: '2026-06', income: 0, expense: 0, net: 0),
        CashflowPoint(month: '2026-07', income: 0, expense: 0, net: 0),
        CashflowPoint(month: '2026-08', income: 0, expense: 0, net: 0),
        CashflowPoint(month: '2026-09', income: 0, expense: 0, net: 0),
        CashflowPoint(month: '2026-10', income: 0, expense: 0, net: 0),
        CashflowPoint(month: '2026-11', income: 10300, expense: 41900, net: -31600),
      ],
      dailyCashflowDays: 30,
      dailyCashflow: daily30,
      yearlyCashflowYears: 5,
      yearlyCashflow: const <YearlyCashflowPoint>[
        YearlyCashflowPoint(year: '2022', income: 0, expense: 0, net: 0),
        YearlyCashflowPoint(year: '2023', income: 0, expense: 0, net: 0),
        YearlyCashflowPoint(year: '2024', income: 0, expense: 0, net: 0),
        YearlyCashflowPoint(year: '2025', income: 0, expense: 0, net: 0),
        YearlyCashflowPoint(year: '2026', income: 10300, expense: 41900, net: -31600),
      ],
      cashflowGranularity: CashflowGranularity.monthly,
      netWorthTrend: nwPoints,
      trendDays: 30,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester,
    DashboardState initialState,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'monevo_language': 'th',
      'monevo_buddhist_era': true,
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final User testUser = User(
      id: 'user-1',
      email: 'kunakorn@monevo.app',
      displayName: 'kunakorn',
      baseCurrency: 'THB',
      timezone: 'Asia/Bangkok',
      createdAt: fixedNow,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          secureStorageProvider.overrideWithValue(InMemorySecureStorageService()),
          biometricServiceProvider.overrideWithValue(_NoopBiometricService()),
          authControllerProvider.overrideWith(
            (_) => _SeededAuthController(testUser),
          ),
          settingsControllerProvider.overrideWith(
            (_) => _SeededSettingsController(),
          ),
          appLockControllerProvider.overrideWith(
            (_) => _SeededAppLockController(),
          ),
          accountsControllerProvider.overrideWith(
            (_) => _SeededAccountsController(),
          ),
          categoriesControllerProvider.overrideWith(
            (_) => _SeededCategoriesController(),
          ),
          dashboardControllerProvider.overrideWith(
            (_) => _SeededDashboardController(initialState),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('th'),
          supportedLocales: const <Locale>[Locale('th'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Dashboard 360x800 visual polish fixes', () {
    testWidgets(
      'hero sparkline does not overlap Net Worth amount and labels do not truncate',
      (WidgetTester tester) async {
        await pumpDashboard(tester, buildRealisticState());

        final Finder netWorthText = find.text('-฿36,721.00');
        final Finder sparkline = find.byType(HeroGrowthSparkline);
        expect(netWorthText, findsOneWidget);
        expect(sparkline, findsOneWidget);

        final Rect amountRect = tester.getRect(netWorthText);
        final Rect sparklineRect = tester.getRect(sparkline);
        expect(amountRect.overlaps(sparklineRect), isFalse);

        // Full Thai labels present cleanly without ellipsis overflow exceptions
        expect(find.text('รายรับรวมทั้งหมด'), findsOneWidget);
        expect(find.text('รายจ่ายรวมทั้งหมด'), findsOneWidget);
        expect(find.text('สรุปประจำเดือน'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'chart range buttons use Thai labels and Y-axis stays clear of pills',
      (WidgetTester tester) async {
        await pumpDashboard(tester, buildRealisticState());

        // Scroll to Cashflow card
        await tester.scrollUntilVisible(
          find.text('กราฟรายรับ-รายจ่าย (รายวัน/เดือน/ปี)'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Monthly selectors localized in Thai; legacy English codes removed
        expect(find.text('3 เดือน'), findsOneWidget);
        expect(find.text('6 เดือน'), findsOneWidget);
        expect(find.text('12 เดือน'), findsOneWidget);
        expect(find.text('3M'), findsNothing);
        expect(find.text('6M'), findsNothing);
        expect(find.text('12M'), findsNothing);

        // Yearly selectors localized in Thai
        await tester.tap(find.text('รายปี'));
        await tester.pumpAndSettle();
        expect(find.text('3 ปี'), findsOneWidget);
        expect(find.text('5 ปี'), findsOneWidget);
        expect(find.text('3Y'), findsNothing);
        expect(find.text('5Y'), findsNothing);

        // Switch back to daily -> Thai day labels shown
        await tester.tap(find.text('รายวัน'));
        await tester.pumpAndSettle();
        expect(find.text('7 วัน'), findsWidgets);
        expect(find.text('14 วัน'), findsOneWidget);
        expect(find.text('30 วัน'), findsWidgets);
        expect(find.text('7D'), findsNothing);
        expect(find.text('14D'), findsNothing);
        expect(find.text('30D'), findsNothing);

        // Scroll further down to Net Worth Trend card
        await tester.scrollUntilVisible(
          find.text('แนวโน้มความมั่งคั่งสุทธิ'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('90 วัน'), findsOneWidget);
        expect(find.text('365 วัน'), findsOneWidget);
        expect(find.text('90D'), findsNothing);
        expect(find.text('365D'), findsNothing);

        // No duplicate '-฿36.7K' Y-axis tick and no top tick overlapping 365 วัน pill
        expect(find.text('-฿36.7K'), findsNothing);
        final Rect pillRect = tester.getRect(find.text('365 วัน').last);
        final Finder negativeTopTick = find.text('-฿36.4K');
        if (negativeTopTick.evaluate().isNotEmpty) {
          final Rect tickRect = tester.getRect(negativeTopTick.first);
          expect(tickRect.top, greaterThan(pillRect.bottom));
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '30-day cashflow chart scrolls horizontally to latest date without date overlap',
      (WidgetTester tester) async {
        final DashboardState state = buildRealisticState().copyWith(
          cashflowGranularity: CashflowGranularity.daily,
          dailyCashflowDays: 30,
        );
        await pumpDashboard(tester, state);

        await tester.scrollUntilVisible(
          find.text('กราฟรายรับ-รายจ่าย (รายวัน/เดือน/ปี)'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final Finder scrollFinder = find.byKey(
          const ValueKey<String>('cashflow_scroll_daily_30'),
        );
        expect(scrollFinder, findsOneWidget);

        final SingleChildScrollView scrollView = tester
            .widget<SingleChildScrollView>(scrollFinder);
        final ScrollController controller = scrollView.controller!;
        expect(controller.hasClients, isTrue);
        expect(controller.position.maxScrollExtent, greaterThan(0));
        expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1.0));

        // Swipe hint displayed for scrollable charts (cashflow & trend)
        expect(find.text('เลื่อนกราฟซ้าย-ขวาได้'), findsWidgets);

        // Adjacent dates on the visible right edge do not collide horizontally
        final Finder date12 = find.descendant(
          of: scrollFinder,
          matching: find.text('12/11'),
        );
        final Finder date13 = find.descendant(
          of: scrollFinder,
          matching: find.text('13/11'),
        );
        expect(date12, findsOneWidget);
        expect(date13, findsOneWidget);
        final Rect r12 = tester.getRect(date12);
        final Rect r13 = tester.getRect(date13);
        expect(r12.right, lessThan(r13.left));

        // Dragging right scrolls back toward earlier dates smoothly
        await tester.drag(scrollFinder, const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(controller.offset, lessThan(controller.position.maxScrollExtent));

        expect(tester.takeException(), isNull);
      },
    );
  });
}

