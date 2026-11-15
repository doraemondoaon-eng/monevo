import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/storage/local_cache_service.dart';
import 'package:monevo/core/theme/app_theme.dart';
import 'package:monevo/features/dashboard/data/dashboard_api.dart';
import 'package:monevo/features/dashboard/data/dashboard_repository.dart';
import 'package:monevo/features/dashboard/domain/dashboard_models.dart';
import 'package:monevo/features/dashboard/presentation/dashboard_controller.dart';
import 'package:monevo/features/transactions/data/transactions_api.dart';
import 'package:monevo/features/transactions/data/transactions_repository.dart';
import 'package:monevo/features/transactions/domain/transaction_model.dart';
import 'package:monevo/features/transactions/presentation/expense_screen.dart';
import 'package:monevo/features/transactions/presentation/transactions_controller.dart';
import 'package:monevo/features/transactions/presentation/transfer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SeededDashboardController extends DashboardController {
  _SeededDashboardController(DashboardState initial)
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
    state = initial;
  }
}

class _SeededTransactionsController extends TransactionsController {
  _SeededTransactionsController(TransactionsState initial)
    : super(
        repo: TransactionsRepository(
          api: TransactionsApi(Dio()),
          cache: LocalCacheService(),
        ),
        onTransactionEffect: (_, __) {},
        onSilentDashboardSync: () {},
        onEnqueueOfflineTransaction: ({
          required TransactionType type,
          required int amount,
          required String accountId,
          String? toAccountId,
          String? categoryId,
          required DateTime occurredAt,
          String? payee,
          String? note,
        }) async {
          throw UnimplementedError();
        },
        onSyncSuccess: () {},
        isAuthenticated: false,
      ) {
    state = initial;
  }
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'monevo_language': 'th',
      'monevo_buddhist_era': true,
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const DashboardState dashState = DashboardState(
      selectedMonth: '2026-11',
      summary: DashboardSummary(
        month: '2026-11',
        currency: 'THB',
        netWorth: 0,
        totalAssets: 0,
        totalLiabilities: 0,
        totalIncome: 0,
        totalExpense: 29900,
        income: 0,
        expense: 29900,
        net: -29900,
        savingsRate: 0,
        financialStatus: 'warning',
        previousMonth: PreviousMonthTotals(income: 0, expense: 0),
        accountCount: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dashboardControllerProvider.overrideWith(
            (_) => _SeededDashboardController(dashState),
          ),
          transactionsControllerProvider.overrideWith(
            (_) => _SeededTransactionsController(const TransactionsState()),
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
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ExpenseScreen shows บันทึกรายจ่าย without แนบสลิป cleanly at 360x800',
    (WidgetTester tester) async {
      await pumpScreen(tester, const ExpenseScreen());

      expect(find.text('จัดการรายจ่าย'), findsOneWidget);
      expect(find.text('บันทึกรายจ่าย'), findsOneWidget);
      expect(find.text('บันทึกรายจ่าย / แนบสลิป'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TransferScreen renders transfer management view cleanly at 360x800',
    (WidgetTester tester) async {
      await pumpScreen(tester, const TransferScreen());

      expect(find.text('จัดการโอนเงิน'), findsOneWidget);
      expect(find.text('บันทึกโอนเงิน'), findsOneWidget);
      expect(find.text('ยอดโอนประจำเดือน'), findsOneWidget);
      expect(find.text('ยอดโอนสะสมทั้งหมด'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
