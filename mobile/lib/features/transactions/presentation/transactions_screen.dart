import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../accounts/domain/account_model.dart';
import '../../accounts/presentation/accounts_controller.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/presentation/categories_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/transaction_model.dart';
import 'transaction_tile.dart';
import 'transactions_controller.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double current = _scrollController.position.pixels;
    if (current >= maxScroll - 240) {
      ref.read(transactionsControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      final TransactionFilter current =
          ref.read(transactionsControllerProvider).filter;
      ref.read(transactionsControllerProvider.notifier).updateFilter(
            current.copyWith(query: value),
          );
    });
  }

  Future<void> _pickDateRange(TransactionFilter currentFilter) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange:
          (currentFilter.from != null && currentFilter.to != null)
              ? DateTimeRange(
                  start: currentFilter.from!,
                  end: currentFilter.to!.subtract(const Duration(days: 1)),
                )
              : null,
    );
    if (picked == null || !mounted) {
      return;
    }
    // API contract: `to` is exclusive.
    final DateTime exclusiveEnd = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day + 1,
    );
    await ref.read(transactionsControllerProvider.notifier).updateFilter(
          currentFilter.copyWith(
            from: DateTime(
              picked.start.year,
              picked.start.month,
              picked.start.day,
            ),
            to: exclusiveEnd,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final TransactionsState state = ref.watch(transactionsControllerProvider);
    final AccountsState accountsState = ref.watch(accountsControllerProvider);
    final CategoriesState categoriesState = ref.watch(
      categoriesControllerProvider,
    );
    final bool useBuddhistEra = ref.watch(
      settingsControllerProvider.select(
        (AppSettingsState s) => s.useBuddhistEra,
      ),
    );
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);

    final List<_DayTransactionGroup> dayGroups = _groupTransactionsByDay(
      state.items,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.navTransactions),
        actions: <Widget>[
          if (state.filter.hasActiveFilters)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                ref.read(transactionsControllerProvider.notifier).clearFilters();
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: Text(strings.clear),
            ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: <Widget>[
            // Search & Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: strings.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: <Widget>[
                  // Type filter chips
                  ChoiceChip(
                    label: Text(strings.all),
                    selected: state.filter.type == null,
                    onSelected: (_) {
                      ref
                          .read(transactionsControllerProvider.notifier)
                          .updateFilter(state.filter.copyWith(clearType: true));
                    },
                  ),
                  const SizedBox(width: 8),
                  for (final TransactionType t in TransactionType.values) ...<Widget>[
                    ChoiceChip(
                      label: Text(t.label(strings)),
                      selected: state.filter.type == t,
                      onSelected: (bool sel) {
                        ref
                            .read(transactionsControllerProvider.notifier)
                            .updateFilter(
                              state.filter.copyWith(
                                type: sel ? t : null,
                                clearType: !sel,
                              ),
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Account filter menu
                  _buildAccountFilterChip(
                    state.filter,
                    accountsState,
                    strings,
                  ),
                  const SizedBox(width: 8),
                  // Category filter menu
                  _buildCategoryFilterChip(
                    state.filter,
                    categoriesState,
                    strings,
                  ),
                  const SizedBox(width: 8),
                  // Date range filter chip
                  FilterChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      state.filter.from != null
                          ? AppDateUtils.formatShortDate(
                              state.filter.from!,
                              language: strings.language,
                              useBuddhistEra: useBuddhistEra,
                            )
                          : strings.occurredAt,
                    ),
                    selected: state.filter.from != null,
                    onSelected: (_) => _pickDateRange(state.filter),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildBody(
                state: state,
                dayGroups: dayGroups,
                strings: strings,
                theme: theme,
                useBuddhistEra: useBuddhistEra,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountFilterChip(
    TransactionFilter filter,
    AccountsState accountsState,
    AppStrings strings,
  ) {
    final AccountModel? selectedAcc = accountsState.findById(filter.accountId);
    return PopupMenuButton<String>(
      onSelected: (String value) {
        if (value == '__clear__') {
          ref.read(transactionsControllerProvider.notifier).updateFilter(
                filter.copyWith(clearAccountId: true),
              );
        } else {
          ref.read(transactionsControllerProvider.notifier).updateFilter(
                filter.copyWith(accountId: value),
              );
        }
      },
      itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: '__clear__',
          child: Text('${strings.all} (${strings.account})'),
        ),
        for (final AccountModel acc in accountsState.items)
          PopupMenuItem<String>(
            value: acc.id,
            child: Text(acc.name),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
        label: Text(selectedAcc?.name ?? strings.account),
      ),
    );
  }

  Widget _buildCategoryFilterChip(
    TransactionFilter filter,
    CategoriesState categoriesState,
    AppStrings strings,
  ) {
    final CategoryModel? selectedCat = categoriesState.findById(
      filter.categoryId,
    );
    return PopupMenuButton<String>(
      onSelected: (String value) {
        if (value == '__clear__') {
          ref.read(transactionsControllerProvider.notifier).updateFilter(
                filter.copyWith(clearCategoryId: true),
              );
        } else {
          ref.read(transactionsControllerProvider.notifier).updateFilter(
                filter.copyWith(categoryId: value),
              );
        }
      },
      itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: '__clear__',
          child: Text('${strings.all} (${strings.category})'),
        ),
        for (final CategoryModel cat in categoriesState.items)
          PopupMenuItem<String>(
            value: cat.id,
            child: Text(cat.name),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.category_outlined, size: 16),
        label: Text(selectedCat?.name ?? strings.category),
      ),
    );
  }

  Widget _buildBody({
    required TransactionsState state,
    required List<_DayTransactionGroup> dayGroups,
    required AppStrings strings,
    required ThemeData theme,
    required bool useBuddhistEra,
  }) {
    if (state.isLoading && state.items.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const SkeletonBox(height: 76),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ErrorStateView(
        message: state.error!.localizedMessage(strings),
        onRetry: () =>
            ref.read(transactionsControllerProvider.notifier).loadInitial(),
      );
    }

    if (dayGroups.isEmpty) {
      return EmptyStateView(
        icon: Icons.receipt_long_rounded,
        title: strings.noData,
        subtitle: strings.tr(
          'ยังไม่มีรายการธุรกรรมในช่วงหรือตัวกรองที่เลือก',
          'No transactions match your current filters',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(transactionsControllerProvider.notifier).loadInitial(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        itemCount: dayGroups.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= dayGroups.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final _DayTransactionGroup group = dayGroups[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        AppDateUtils.formatDayHeader(
                          group.day,
                          strings: strings,
                          useBuddhistEra: useBuddhistEra,
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AmountText(
                        satang: group.netSatang,
                        showPlusSign: true,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: group.netSatang >= 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < group.items.length; i++) ...<Widget>[
                        if (i > 0)
                          const Divider(indent: 72, endIndent: 16, height: 1),
                        TransactionTile(
                          transaction: group.items[i],
                          onTap: () => context.push(
                            '/transactions/${group.items[i].id}',
                            extra: group.items[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_DayTransactionGroup> _groupTransactionsByDay(
    List<TransactionModel> transactions,
  ) {
    final Map<String, _DayTransactionGroup> map =
        <String, _DayTransactionGroup>{};
    for (final TransactionModel tx in transactions) {
      final DateTime local = tx.occurredAt.toLocal();
      final DateTime dayKeyDate = DateTime(local.year, local.month, local.day);
      final String key = AppDateUtils.toApiDate(dayKeyDate);

      final _DayTransactionGroup existing = map.putIfAbsent(
        key,
        () => _DayTransactionGroup(day: dayKeyDate),
      );
      existing.items.add(tx);
      if (tx.type == TransactionType.income) {
        existing.netSatang += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        existing.netSatang -= tx.amount;
      }
    }
    return map.values.toList();
  }
}

class _DayTransactionGroup {
  _DayTransactionGroup({required this.day});

  final DateTime day;
  final List<TransactionModel> items = <TransactionModel>[];
  int netSatang = 0;
}
