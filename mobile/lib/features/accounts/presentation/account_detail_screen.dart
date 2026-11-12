import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../transactions/data/transactions_api.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/transaction_form_sheet.dart';
import '../../transactions/presentation/transaction_tile.dart';
import '../domain/account_model.dart';
import 'account_form_sheet.dart';
import 'accounts_controller.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({
    super.key,
    required this.accountId,
  });

  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  List<TransactionModel> _transactions = <TransactionModel>[];
  String? _nextCursor;
  bool _loadingTx = true;
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    _loadAccountTransactions();
  }

  Future<void> _loadAccountTransactions() async {
    setState(() => _loadingTx = true);
    try {
      final PaginatedTransactions page = await ref
          .read(transactionsApiProvider)
          .getTransactions(
            filter: TransactionFilter(accountId: widget.accountId),
            limit: 50,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _transactions = page.items;
        _nextCursor = page.nextCursor;
        _loadingTx = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingTx = false);
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _nextCursor!.isEmpty) {
      return;
    }
    try {
      final PaginatedTransactions page = await ref
          .read(transactionsApiProvider)
          .getTransactions(
            filter: TransactionFilter(accountId: widget.accountId),
            cursor: _nextCursor,
            limit: 50,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _transactions = <TransactionModel>[..._transactions, ...page.items];
        _nextCursor = page.nextCursor;
      });
    } catch (_) {}
  }

  Future<void> _handleReconcile(AccountModel account) async {
    final AppStrings strings = AppStrings.of(context);
    setState(() => _reconciling = true);
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(accountsControllerProvider.notifier)
          .reconcileAccount(account.id);
      ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      setState(() => _reconciling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.reconcileSuccess)),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _reconciling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.localizedMessage(strings))),
      );
    }
  }

  Future<void> _handleDelete(AccountModel account) async {
    final AppStrings strings = AppStrings.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(strings.delete),
          content: Text(
            strings.tr(
              'ต้องการลบบัญชี "${account.name}" ใช่หรือไม่?',
              'Delete account "${account.name}"?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(accountsControllerProvider.notifier)
          .deleteAccount(account.id);
      ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.isAccountHasTransactions) {
        final bool? archiveInstead = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: Text(strings.archive),
              content: Text(e.localizedMessage(strings)),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(strings.archive),
                ),
              ],
            );
          },
        );
        if (archiveInstead == true && mounted) {
          await ref
              .read(accountsControllerProvider.notifier)
              .updateAccount(account.id, isArchived: true);
          ref.read(dashboardControllerProvider.notifier).refresh();
          if (!mounted) {
            return;
          }
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(strings))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AccountsState accountsState = ref.watch(accountsControllerProvider);
    final AccountModel? account = accountsState.findById(widget.accountId);
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);

    if (account == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyStateView(
          icon: Icons.account_balance_wallet_outlined,
          title: strings.noData,
        ),
      );
    }

    final Color accColor = AppColors.fromHex(account.color);

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await showModalBottomSheet<AccountModel>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => AccountFormSheet(existing: account),
              );
            },
            tooltip: strings.editAccount,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'reconcile') {
                await _handleReconcile(account);
              } else if (value == 'archive') {
                await ref
                    .read(accountsControllerProvider.notifier)
                    .updateAccount(
                      account.id,
                      isArchived: !account.isArchived,
                    );
                ref.read(dashboardControllerProvider.notifier).refresh();
              } else if (value == 'delete') {
                await _handleDelete(account);
              }
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'reconcile',
                child: Text(strings.reconcileAccount),
              ),
              PopupMenuItem<String>(
                value: 'archive',
                child: Text(
                  account.isArchived ? strings.unarchive : strings.archive,
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  strings.delete,
                  style: const TextStyle(color: AppColors.expense),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final bool? added = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => TransactionFormSheet(initialAccountId: account.id),
          );
          if (added == true) {
            await _loadAccountTransactions();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.addTransaction),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(accountsControllerProvider.notifier).loadAccounts();
            await _loadAccountTransactions();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: <Widget>[
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accColor.withAlpha(32),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            IconMapper.resolve(account.icon),
                            color: accColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                account.type.label(strings),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: accColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                account.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (account.subtitle.isNotEmpty)
                                Text(
                                  account.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      strings.currentBalance,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      satang: account.balance,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: account.balance < 0
                            ? AppColors.expense
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '${strings.openingBalance}: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        AmountText(
                          satang: account.openingBalance,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _reconciling
                          ? null
                          : () => _handleReconcile(account),
                      icon: _reconciling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(strings.reconcileAccount),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.navTransactions,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingTx)
                const Column(
                  children: <Widget>[
                    SkeletonBox(height: 72),
                    SizedBox(height: 10),
                    SkeletonBox(height: 72),
                  ],
                )
              else if (_transactions.isEmpty)
                EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: strings.noData,
                )
              else
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < _transactions.length; i++) ...<Widget>[
                        if (i > 0)
                          const Divider(indent: 72, endIndent: 16, height: 1),
                        TransactionTile(
                          transaction: _transactions[i],
                          showDate: true,
                          onTap: () async {
                            await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => TransactionFormSheet(
                                existing: _transactions[i],
                              ),
                            );
                            await _loadAccountTransactions();
                          },
                        ),
                      ],
                      if (_nextCursor != null && _nextCursor!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextButton(
                            onPressed: _loadMore,
                            child: Text(strings.viewAll),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
