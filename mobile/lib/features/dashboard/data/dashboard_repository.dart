import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_cache_service.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_api.dart';

class DashboardRepository {
  const DashboardRepository({
    required DashboardApi api,
    required LocalCacheService cache,
  }) : _api = api,
       _cache = cache;

  final DashboardApi _api;
  final LocalCacheService _cache;

  Future<DashboardSummary?> getCachedSummary(String month) async {
    final Map<String, dynamic>? raw = await _cache.readJsonMap(
      LocalCacheService.summaryKey(month),
    );
    if (raw == null) {
      return null;
    }
    return DashboardSummary.fromJson(raw);
  }

  Future<DashboardSummary> getSummary({String? month}) async {
    final DashboardSummary summary = await _api.getSummary(month: month);
    await _cache.writeJsonMap(
      LocalCacheService.summaryKey(summary.month),
      summary.toJson(),
    );
    return summary;
  }

  Future<List<CashflowPoint>> getCashflow({int months = 6}) =>
      _api.getCashflow(months: months);

  Future<List<DailyCashflowPoint>> getDailyCashflow({int days = 14}) =>
      _api.getDailyCashflow(days: days);

  Future<List<YearlyCashflowPoint>> getYearlyCashflow({int years = 5}) =>
      _api.getYearlyCashflow(years: years);

  Future<AccountBalancesOverview> getAccountBalancesOverview() =>
      _api.getAccountBalancesOverview();

  Future<CategoryBreakdown> getCategoryBreakdown({
    String type = 'expense',
    String? month,
  }) => _api.getCategoryBreakdown(type: type, month: month);

  Future<List<NetWorthPoint>> getNetWorthTrend({int days = 30}) =>
      _api.getNetWorthTrend(days: days);
}

final Provider<DashboardRepository> dashboardRepositoryProvider =
    Provider<DashboardRepository>((Ref ref) {
      return DashboardRepository(
        api: ref.watch(dashboardApiProvider),
        cache: ref.watch(localCacheServiceProvider),
      );
    });

