import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/accounts_repository.dart';
import '../domain/account_model.dart';

class AccountsState {
  const AccountsState({
    this.items = const <AccountModel>[],
    this.isLoading = false,
    this.includeArchived = false,
    this.error,
  });

  final List<AccountModel> items;
  final bool isLoading;
  final bool includeArchived;
  final ApiException? error;

  List<AccountModel> get activeAccounts =>
      items.where((AccountModel a) => !a.isArchived).toList();

  AccountModel? findById(String? id) {
    if (id == null) {
      return null;
    }
    for (final AccountModel item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  int get totalNetWorthSatang {
    int sum = 0;
    for (final AccountModel a in items) {
      if (!a.isArchived && a.includeInNetWorth) {
        sum += a.balance;
      }
    }
    return sum;
  }

  int get totalAssetsSatang {
    int sum = 0;
    for (final AccountModel a in items) {
      if (!a.isArchived && a.includeInNetWorth && a.balance > 0) {
        sum += a.balance;
      }
    }
    return sum;
  }

  int get totalLiabilitiesSatang {
    int sum = 0;
    for (final AccountModel a in items) {
      if (!a.isArchived && a.includeInNetWorth && a.balance < 0) {
        sum += a.balance.abs();
      }
    }
    return sum;
  }

  Map<AccountType, List<AccountModel>> get groupedByType {
    final Map<AccountType, List<AccountModel>> map =
        <AccountType, List<AccountModel>>{};
    for (final AccountModel acc in items) {
      map.putIfAbsent(acc.type, () => <AccountModel>[]).add(acc);
    }
    return map;
  }

  AccountsState copyWith({
    List<AccountModel>? items,
    bool? isLoading,
    bool? includeArchived,
    ApiException? error,
    bool clearError = false,
  }) {
    return AccountsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      includeArchived: includeArchived ?? this.includeArchived,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccountsController extends StateNotifier<AccountsState> {
  AccountsController(this._repo, {required bool isAuthenticated})
    : super(const AccountsState()) {
    if (isAuthenticated) {
      _hydrateAndLoad();
    }
  }

  final AccountsRepository _repo;

  Future<void> _hydrateAndLoad() async {
    final List<AccountModel> cached = await _repo.getCachedAccounts();
    if (mounted && cached.isNotEmpty && state.items.isEmpty) {
      state = state.copyWith(items: cached);
    }
    await loadAccounts();
  }

  Future<void> loadAccounts({bool? includeArchived}) async {
    final bool targetInclude = includeArchived ?? state.includeArchived;
    state = state.copyWith(
      isLoading: true,
      includeArchived: targetInclude,
      clearError: true,
    );
    try {
      final List<AccountModel> list = await _repo.getAccounts(
        includeArchived: targetInclude,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        items: list,
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

  Future<AccountModel> createAccount({
    required String name,
    required AccountType type,
    String? institution,
    String? accountNumberLast4,
    int openingBalance = 0,
    required String color,
    required String icon,
    bool includeInNetWorth = true,
  }) async {
    final AccountModel created = await _repo.createAccount(
      name: name,
      type: type,
      institution: institution,
      accountNumberLast4: accountNumberLast4,
      openingBalance: openingBalance,
      color: color,
      icon: icon,
      includeInNetWorth: includeInNetWorth,
    );
    state = state.copyWith(
      items: <AccountModel>[...state.items, created],
    );
    return created;
  }

  Future<AccountModel> updateAccount(
    String id, {
    String? name,
    AccountType? type,
    String? institution,
    String? accountNumberLast4,
    int? openingBalance,
    String? color,
    String? icon,
    bool? includeInNetWorth,
    bool? isArchived,
    int? sortOrder,
  }) async {
    final AccountModel updated = await _repo.updateAccount(
      id,
      name: name,
      type: type,
      institution: institution,
      accountNumberLast4: accountNumberLast4,
      openingBalance: openingBalance,
      color: color,
      icon: icon,
      includeInNetWorth: includeInNetWorth,
      isArchived: isArchived,
      sortOrder: sortOrder,
    );
    final List<AccountModel> next = state.items
        .map((AccountModel a) => a.id == id ? updated : a)
        .where((AccountModel a) => state.includeArchived || !a.isArchived)
        .toList();
    state = state.copyWith(items: next);
    return updated;
  }

  Future<AccountModel> reconcileAccount(String id) async {
    final AccountModel reconciled = await _repo.reconcileAccount(id);
    final List<AccountModel> next = state.items
        .map((AccountModel a) => a.id == id ? reconciled : a)
        .toList();
    state = state.copyWith(items: next);
    return reconciled;
  }

  Future<void> deleteAccount(String id) async {
    await _repo.deleteAccount(id);
    state = state.copyWith(
      items: state.items.where((AccountModel a) => a.id != id).toList(),
    );
  }

  /// Section 10 Performance Optimization:
  /// Applies a transaction's balance impact in-place in memory (`direction` = `+1` or `-1`)
  /// so recording/editing/deleting a transaction updates account balances immediately
  /// without setting `isLoading = true` or reloading the entire app.
  void applyBalanceDeltaInPlace({
    required String accountId,
    required int deltaSatang,
  }) {
    final List<AccountModel> next = state.items.map((AccountModel a) {
      if (a.id == accountId) {
        return a.copyWith(
          balance: a.balance + deltaSatang,
          updatedAt: DateTime.now(),
        );
      }
      return a;
    }).toList();
    state = state.copyWith(items: next);
  }
}

final StateNotifierProvider<AccountsController, AccountsState>
accountsControllerProvider =
    StateNotifierProvider<AccountsController, AccountsState>((Ref ref) {
      final bool isAuthenticated = ref.watch(
        authControllerProvider.select((AuthState s) => s.isAuthenticated),
      );
      return AccountsController(
        ref.watch(accountsRepositoryProvider),
        isAuthenticated: isAuthenticated,
      );
    });
