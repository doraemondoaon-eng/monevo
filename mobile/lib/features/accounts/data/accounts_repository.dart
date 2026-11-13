import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_cache_service.dart';
import '../domain/account_model.dart';
import 'accounts_api.dart';

class AccountsRepository {
  const AccountsRepository({
    required AccountsApi api,
    required LocalCacheService cache,
  }) : _api = api,
       _cache = cache;

  final AccountsApi _api;
  final LocalCacheService _cache;

  Future<List<AccountModel>> getCachedAccounts() async {
    final List<Map<String, dynamic>>? raw = await _cache.readJsonList(
      LocalCacheService.keyAccounts,
    );
    if (raw == null) {
      return const <AccountModel>[];
    }
    return raw.map(AccountModel.fromJson).toList();
  }

  Future<List<AccountModel>> getAccounts({
    bool includeArchived = false,
  }) async {
    final List<AccountModel> list = await _api.getAccounts(
      includeArchived: includeArchived,
    );
    if (!includeArchived) {
      await _cache.writeJsonList(
        LocalCacheService.keyAccounts,
        list.map((AccountModel a) => a.toJson()).toList(),
      );
    }
    return list;
  }

  Future<AccountModel> getAccount(String id) => _api.getAccount(id);

  Future<AccountModel> createAccount({
    required String name,
    required AccountType type,
    String? institution,
    String? accountNumberLast4,
    String currency = 'THB',
    int openingBalance = 0,
    String? color,
    String? icon,
    bool includeInNetWorth = true,
  }) {
    return _api.createAccount(
      name: name,
      type: type,
      institution: institution,
      accountNumberLast4: accountNumberLast4,
      currency: currency,
      openingBalance: openingBalance,
      color: color,
      icon: icon,
      includeInNetWorth: includeInNetWorth,
    );
  }

  Future<AccountModel> updateAccount(
    String id, {
    String? name,
    AccountType? type,
    String? institution,
    bool clearInstitution = false,
    String? accountNumberLast4,
    bool clearLast4 = false,
    int? openingBalance,
    String? color,
    String? icon,
    bool? includeInNetWorth,
    bool? isArchived,
    int? sortOrder,
  }) {
    return _api.updateAccount(
      id,
      name: name,
      type: type,
      institution: institution,
      clearInstitution: clearInstitution,
      accountNumberLast4: accountNumberLast4,
      clearLast4: clearLast4,
      openingBalance: openingBalance,
      color: color,
      icon: icon,
      includeInNetWorth: includeInNetWorth,
      isArchived: isArchived,
      sortOrder: sortOrder,
    );
  }

  Future<void> deleteAccount(String id, {bool cascade = false}) =>
      _api.deleteAccount(id, cascade: cascade);

  Future<AccountModel> reconcileAccount(String id) =>
      _api.reconcileAccount(id);
}

final Provider<AccountsRepository> accountsRepositoryProvider =
    Provider<AccountsRepository>((Ref ref) {
      return AccountsRepository(
        api: ref.watch(accountsApiProvider),
        cache: ref.watch(localCacheServiceProvider),
      );
    });

