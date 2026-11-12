import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

enum CashflowGranularity { daily, monthly, yearly }

class DashboardState {
  const DashboardState({
    required this.selectedMonth,
    this.summary,
    this.cashflow = const <CashflowPoint>[],
    this.cashflowMonths = 6,
    this.dailyCashflow = const <DailyCashflowPoint>[],
    this.dailyCashflowDays = 14,
    this.yearlyCashflow = const <YearlyCashflowPoint>[],
    this.yearlyCashflowYears = 5,
    this.cashflowGranularity = CashflowGranularity.monthly,
    this.accountBalancesOverview,
    this.categoryBreakdown,
    this.categoryType = 'expense',
    this.netWorthTrend = const <NetWorthPoint>[],
    this.trendDays = 30,
    this.recentTransactions = const <TransactionModel>[],
    this.isLoading = false,
    this.error,
  });

  final String selectedMonth;
  final DashboardSummary? summary;
  final List<CashflowPoint> cashflow;
  final int cashflowMonths;
  final List<DailyCashflowPoint> dailyCashflow;
  final int dailyCashflowDays;
  final List<YearlyCashflowPoint> yearlyCashflow;
  final int yearlyCashflowYears;
  final CashflowGranularity cashflowGranularity;
  final AccountBalancesOverview? accountBalancesOverview;
  final CategoryBreakdown? categoryBreakdown;
  final String categoryType;
  final List<NetWorthPoint> netWorthTrend;
  final int trendDays;
  final List<TransactionModel> recentTransactions;
  final bool isLoading;
  final ApiException? error;

  DashboardState copyWith({
    String? selectedMonth,
    DashboardSummary? summary,
    List<CashflowPoint>? cashflow,
    int? cashflowMonths,
    List<DailyCashflowPoint>? dailyCashflow,
    int? dailyCashflowDays,
    List<YearlyCashflowPoint>? yearlyCashflow,
    int? yearlyCashflowYears,
    CashflowGranularity? cashflowGranularity,
    AccountBalancesOverview? accountBalancesOverview,
    CategoryBreakdown? categoryBreakdown,
    String? categoryType,
    List<NetWorthPoint>? netWorthTrend,
    int? trendDays,
    List<TransactionModel>? recentTransactions,
    bool? isLoading,
    ApiException? error,
    bool clearError = false,
  }) {
    return DashboardState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      summary: summary ?? this.summary,
      cashflow: cashflow ?? this.cashflow,
      cashflowMonths: cashflowMonths ?? this.cashflowMonths,
      dailyCashflow: dailyCashflow ?? this.dailyCashflow,
      dailyCashflowDays: dailyCashflowDays ?? this.dailyCashflowDays,
      yearlyCashflow: yearlyCashflow ?? this.yearlyCashflow,
      yearlyCashflowYears: yearlyCashflowYears ?? this.yearlyCashflowYears,
      cashflowGranularity: cashflowGranularity ?? this.cashflowGranularity,
      accountBalancesOverview:
          accountBalancesOverview ?? this.accountBalancesOverview,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      categoryType: categoryType ?? this.categoryType,
      netWorthTrend: netWorthTrend ?? this.netWorthTrend,
      trendDays: trendDays ?? this.trendDays,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController({
    required DashboardRepository dashboardRepo,
    required TransactionsRepository transactionsRepo,
    required bool isAuthenticated,
  }) : _dashboardRepo = dashboardRepo,
       _transactionsRepo = transactionsRepo,
       super(
         DashboardState(
           selectedMonth: AppDateUtils.toApiMonth(DateTime.now()),
         ),
       ) {
    if (isAuthenticated) {
      _hydrateAndRefresh();
    }
  }

  final DashboardRepository _dashboardRepo;
  final TransactionsRepository _transactionsRepo;

  Future<void> _hydrateAndRefresh() async {
    final DashboardSummary? cachedSummary =
        await _dashboardRepo.getCachedSummary(state.selectedMonth);
    final List<TransactionModel> cachedRecent =
        await _transactionsRepo.getCachedRecentTransactions();
    if (mounted && (cachedSummary != null || cachedRecent.isNotEmpty)) {
      state = state.copyWith(
        summary: cachedSummary ?? state.summary,
        recentTransactions: cachedRecent.isNotEmpty
            ? cachedRecent.take(5).toList()
            : state.recentTransactions,
      );
    }
    await refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final String month = state.selectedMonth;
      final String catType = state.categoryType;
      final int days = state.trendDays;

      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _dashboardRepo.getSummary(month: month),
        _dashboardRepo.getCashflow(months: state.cashflowMonths),
        _dashboardRepo.getDailyCashflow(days: state.dailyCashflowDays),
        _dashboardRepo.getYearlyCashflow(years: state.yearlyCashflowYears),
        _dashboardRepo.getAccountBalancesOverview(),
        _dashboardRepo.getCategoryBreakdown(type: catType, month: month),
        _dashboardRepo.getNetWorthTrend(days: days),
        _transactionsRepo.getTransactions(limit: 5),
      ]);

      if (!mounted) {
        return;
      }

      state = state.copyWith(
        summary: results[0] as DashboardSummary,
        cashflow: results[1] as List<CashflowPoint>,
        dailyCashflow: results[2] as List<DailyCashflowPoint>,
        yearlyCashflow: results[3] as List<YearlyCashflowPoint>,
        accountBalancesOverview: results[4] as AccountBalancesOverview,
        categoryBreakdown: results[5] as CategoryBreakdown,
        netWorthTrend: results[6] as List<NetWorthPoint>,
        recentTransactions: (results[7] as PaginatedTransactions).items,
        isLoading: false,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> selectMonth(DateTime monthDate) async {
    final String nextMonth = AppDateUtils.toApiMonth(monthDate);
    if (nextMonth == state.selectedMonth) {
      return;
    }
    state = state.copyWith(selectedMonth: nextMonth);
    await refresh();
  }

  Future<void> stepMonth(int deltaMonths) async {
    final DateTime current = AppDateUtils.parseApiMonth(state.selectedMonth);
    final DateTime next = DateTime(current.year, current.month + deltaMonths, 1);
    await selectMonth(next);
  }

  Future<void> setCategoryType(String type) async {
    if (type == state.categoryType) {
      return;
    }
    state = state.copyWith(categoryType: type);
    try {
      final CategoryBreakdown breakdown =
          await _dashboardRepo.getCategoryBreakdown(
            type: type,
            month: state.selectedMonth,
          );
      if (!mounted) {
        return;
      }
      state = state.copyWith(categoryBreakdown: breakdown);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(error: e);
    }
  }

  Future<void> setTrendDays(int days) async {
    if (days == state.trendDays) {
      return;
    }
    state = state.copyWith(trendDays: days);
    try {
      final List<NetWorthPoint> trend =
          await _dashboardRepo.getNetWorthTrend(days: days);
      if (!mounted) {
        return;
      }
      state = state.copyWith(netWorthTrend: trend);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(error: e);
    }
  }

  void setCashflowGranularity(CashflowGranularity granularity) {
    if (granularity == state.cashflowGranularity) {
      return;
    }
    state = state.copyWith(cashflowGranularity: granularity);
  }

  Future<void> setDailyCashflowDays(int days) async {
    if (days == state.dailyCashflowDays) {
      return;
    }
    state = state.copyWith(dailyCashflowDays: days);
    try {
      final List<DailyCashflowPoint> rows =
          await _dashboardRepo.getDailyCashflow(days: days);
      if (!mounted) {
        return;
      }
      state = state.copyWith(dailyCashflow: rows);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(error: e);
    }
  }

  Future<void> setCashflowMonths(int months) async {
    if (months == state.cashflowMonths) {
      return;
    }
    state = state.copyWith(cashflowMonths: months);
    try {
      final List<CashflowPoint> rows =
          await _dashboardRepo.getCashflow(months: months);
      if (!mounted) {
        return;
      }
      state = state.copyWith(cashflow: rows);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(error: e);
    }
  }

  Future<void> setYearlyCashflowYears(int years) async {
    if (years == state.yearlyCashflowYears) {
      return;
    }
    state = state.copyWith(yearlyCashflowYears: years);
    try {
      final List<YearlyCashflowPoint> rows =
          await _dashboardRepo.getYearlyCashflow(years: years);
      if (!mounted) {
        return;
      }
      state = state.copyWith(yearlyCashflow: rows);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(error: e);
    }
  }
}

final StateNotifierProvider<DashboardController, DashboardState>
dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((Ref ref) {
      final bool isAuthenticated = ref.watch(
        authControllerProvider.select((AuthState s) => s.isAuthenticated),
      );
      return DashboardController(
        dashboardRepo: ref.watch(dashboardRepositoryProvider),
        transactionsRepo: ref.watch(transactionsRepositoryProvider),
        isAuthenticated: isAuthenticated,
      );
    });
