import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/monevo_feedback.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../transactions/data/transactions_api.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/transactions_controller.dart';
import '../domain/account_model.dart';
import 'account_form_sheet.dart';
import 'accounts_controller.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _openCreateSheet(BuildContext context) async {
    await showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AccountFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AccountsState state = ref.watch(accountsControllerProvider);
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.accountsTitle),
        actions: <Widget>[
          FilterChip(
            label: Text(strings.showArchived),
            selected: state.includeArchived,
            onSelected: (bool val) {
              ref
                  .read(accountsControllerProvider.notifier)
                  .loadAccounts(includeArchived: val);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _openCreateSheet(context),
            tooltip: strings.addAccount,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveCenter(
        child: _buildBody(context, ref, state, strings, theme),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AccountsState state,
    AppStrings strings,
    ThemeData theme,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => const SkeletonBox(height: 86),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ErrorStateView(
        message: state.error!.localizedMessage(strings),
        onRetry: () =>
            ref.read(accountsControllerProvider.notifier).loadAccounts(),
      );
    }

    if (state.items.isEmpty) {
      return EmptyStateView(
        icon: Icons.account_balance_wallet_outlined,
        title: strings.tr('ยังไม่มีบัญชีการเงิน', 'No Accounts Yet'),
        subtitle: strings.tr(
          'เพิ่มบัญชีธนาคาร เงินสด บัตรเครดิต หรืออีวอลเล็ท เพื่อเริ่มติดตามความมั่งคั่ง',
          'Add your bank, cash, credit card, or e-wallet accounts to track your wealth.',
        ),
        actionLabel: strings.addAccount,
        onAction: () => _openCreateSheet(context),
      );
    }

    final Map<AccountType, List<AccountModel>> grouped = state.groupedByType;

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(accountsControllerProvider.notifier).loadAccounts(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: <Widget>[
          // Net Worth Summary Banner
          PremiumCard(
            gradient: const LinearGradient(
              colors: <Color>[
                AppColors.heroStart,
                AppColors.heroMiddle,
                AppColors.heroEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.netWorthTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 6),
                AmountText(
                  satang: state.totalNetWorthSatang,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _NetWorthSubMetric(
                        label: strings.totalAssets,
                        satang: state.totalAssetsSatang,
                        color: const Color(0xFF6EE7B7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NetWorthSubMetric(
                        label: strings.totalLiabilities,
                        satang: state.totalLiabilitiesSatang,
                        color: const Color(0xFFFDA4AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Grouped Accounts
          for (final AccountType type in AccountType.values)
            if (grouped[type] != null && grouped[type]!.isNotEmpty) ...<Widget>[
              _AccountGroupSection(
                type: type,
                accounts: grouped[type]!,
                strings: strings,
              ),
              const SizedBox(height: 18),
            ],
        ],
      ),
    );
  }
}

class _NetWorthSubMetric extends StatelessWidget {
  const _NetWorthSubMetric({
    required this.label,
    required this.satang,
    required this.color,
  });

  final String label;
  final int satang;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withAlpha(190),
            ),
          ),
          const SizedBox(height: 4),
          AmountText(
            satang: satang,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountGroupSection extends StatelessWidget {
  const _AccountGroupSection({
    required this.type,
    required this.accounts,
    required this.strings,
  });

  final AccountType type;
  final List<AccountModel> accounts;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int groupTotalSatang = accounts.fold<int>(
      0,
      (int sum, AccountModel a) => sum + a.balance,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                type.label(strings),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AmountText(
                satang: groupTotalSatang,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < accounts.length; i++) ...<Widget>[
                if (i > 0) const Divider(indent: 70, endIndent: 16, height: 1),
                _AccountListTile(account: accounts[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountListTile extends ConsumerWidget {
  const _AccountListTile({required this.account});

  final AccountModel account;

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final bool confirmed = await MonevoAlert.showConfirm(
      context,
      title: strings.tr(
        'ลบบัญชี "${account.name}"?',
        'Delete account "${account.name}"?',
      ),
      message: strings.tr(
        'หากยืนยันลบ ระบบจะลบบัญชีนี้พร้อมทั้งรายการธุรกรรมทั้งหมดที่เกี่ยวข้องออกอย่างถาวร',
        'Confirming will permanently delete this account and all associated transactions.',
      ),
      confirmLabel: strings.tr(
        'ลบบัญชีและธุรกรรมทั้งหมด',
        'Delete Account & Transactions',
      ),
      cancelLabel: strings.cancel,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed) return;

    try {
      await ref
          .read(accountsControllerProvider.notifier)
          .deleteAccountCascade(
            account.id,
            onCleanupTransactions: (String accId) async {
              final TransactionsApi api = ref.read(transactionsApiProvider);
              final TransactionsRepository repo = ref.read(
                transactionsRepositoryProvider,
              );
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

      final BuildContext? targetContext = rootNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        MonevoAlert.showSuccess(
          targetContext,
          title: strings.tr('ลบบัญชีสำเร็จ!', 'Account Deleted!'),
          subtitle: strings.tr(
            'ลบบัญชี "${account.name}" เรียบร้อยแล้ว',
            'Account "${account.name}" removed.',
          ),
        );
      }
    } catch (e) {
      final BuildContext? targetContext = rootNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        MonevoAlert.showError(
          targetContext,
          title: strings.tr('ไม่สามารถลบบัญชีได้', 'Failed to delete account'),
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppStrings strings = AppStrings.of(context);
    final Color color = AppColors.fromHex(account.color);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/accounts/${account.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                IconMapper.resolve(account.icon),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    account.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: account.isArchived
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (account.subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      account.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                AmountText(
                  satang: account.balance,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: account.balance < 0
                        ? AppColors.expense
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (!account.includeInNetWorth)
                  Text(
                    'Excluded',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (String val) async {
                if (val == 'edit') {
                  await showModalBottomSheet<AccountModel>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => AccountFormSheet(existing: account),
                  );
                } else if (val == 'delete') {
                  await _handleDelete(context, ref, strings);
                }
              },
              itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(strings.edit),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.expense,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.delete,
                        style: const TextStyle(color: AppColors.expense),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
