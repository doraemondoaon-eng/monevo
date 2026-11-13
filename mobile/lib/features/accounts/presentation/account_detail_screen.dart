import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/account_badge.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/monevo_feedback.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../transactions/data/transactions_api.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/transaction_form_sheet.dart';
import '../../transactions/presentation/transaction_tile.dart';
import '../../transactions/presentation/transactions_controller.dart';
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
    final bool hasTx = _transactions.isNotEmpty;
    final bool confirmed = await MonevoAlert.showConfirm(
      context,
      title: strings.tr('ลบบัญชี "${account.name}"?', 'Delete account "${account.name}"?'),
      message: hasTx
          ? strings.tr(
              'บัญชีนี้มีรายการธุรกรรมอยู่ หากยืนยันลบ ระบบจะลบบัญชีพร้อมทั้งรายการธุรกรรมทั้งหมดในบัญชีนี้ออกด้วย',
              'This account has transactions. Confirming will delete this account along with all associated transactions.',
            )
          : strings.tr(
              'คุณต้องการลบบัญชีนี้ใช่หรือไม่?',
              'Are you sure you want to delete this account?',
            ),
      confirmLabel: hasTx
          ? strings.tr('ลบบัญชีและธุรกรรมทั้งหมด', 'Delete Account & Transactions')
          : strings.delete,
      cancelLabel: strings.cancel,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref.read(accountsControllerProvider.notifier).deleteAccountCascade(
        account.id,
        onCleanupTransactions: (String accId) async {
          final TransactionsApi api = ref.read(transactionsApiProvider);
          final TransactionsRepository repo =
              ref.read(transactionsRepositoryProvider);
          final PaginatedTransactions page = await api.getTransactions(
            filter: TransactionFilter(accountId: accId),
            limit: 100,
          );
          for (final TransactionModel tx in page.items) {
            try {
              await repo.deleteTransaction(tx.id);
            } catch (_) {}
          }
        },
      );
      ref.read(dashboardControllerProvider.notifier).refresh();
      ref.read(transactionsControllerProvider.notifier).loadInitial();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();

      final BuildContext? targetContext = rootNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        MonevoAlert.showSuccess(
          targetContext,
          title: strings.tr('ลบบัญชีสำเร็จ!', 'Account Deleted!'),
          subtitle: strings.tr(
            'ลบบัญชี "${account.name}" และรายการที่เกี่ยวข้องเรียบร้อยแล้ว',
            'Account "${account.name}" and associated records have been removed.',
          ),
          customIcon: Icons.delete_sweep_rounded,
          customColor: AppColors.expense,
          confirmLabel: strings.confirm,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      MonevoAlert.showError(
        context,
        title: strings.tr('ไม่สามารถลบบัญชีได้', 'Failed to delete account'),
        message: e.localizedMessage(strings),
      );
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
                        AccountBrandAvatar(
                          institution: account.institution,
                          accountName: account.name,
                          iconKey: account.icon,
                          colorHex: account.color,
                          size: 52,
                          borderRadius: 16,
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
                            await showModalBottomSheet<dynamic>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => TransactionFormSheet(
                                existing: _transactions[i],
                              ),
                            );
                            if (mounted) {
                              await _loadAccountTransactions();
                              ref
                                  .read(accountsControllerProvider.notifier)
                                  .loadAccounts();
                              ref
                                  .read(dashboardControllerProvider.notifier)
                                  .refresh();
                            }
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
              const SizedBox(height: 28),
              BouncyTap(
                onTap: () => _handleDelete(account),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.expense.withAlpha(70)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.expense,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.tr('ลบบัญชีนี้', 'Delete This Account'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.expense,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
