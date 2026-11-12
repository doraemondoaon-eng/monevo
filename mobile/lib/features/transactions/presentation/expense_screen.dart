import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../domain/transaction_model.dart';
import 'transaction_form_sheet.dart';
import 'transaction_tile.dart';
import 'transactions_controller.dart';

/// Section 8.2 Expense Screen (`/expense`):
/// Dedicated view for managing all expense records, monthly vs all-time expense
/// summary, and quick expense creation with local slip/receipt attachment.
class ExpenseScreen extends ConsumerWidget {
  const ExpenseScreen({super.key});

  Future<void> _openAddExpense(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const TransactionFormSheet(
        initialType: TransactionType.expense,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final DashboardSummary? summary = ref.watch(
      dashboardControllerProvider.select((DashboardState s) => s.summary),
    );
    final TransactionsState txState = ref.watch(transactionsControllerProvider);
    final List<TransactionModel> expenseItems = txState.items
        .where((TransactionModel t) => t.type == TransactionType.expense)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('จัดการรายจ่าย', 'Expense Management')),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openAddExpense(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: strings.tr('เพิ่มรายจ่าย', 'Add Expense'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddExpense(context),
        backgroundColor: AppColors.expense,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          strings.tr('บันทึกรายจ่าย / แนบสลิป', 'Record Expense'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: <Widget>[
            PremiumCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.tr('รายจ่ายประจำเดือน', 'Monthly Expense'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AmountText(
                          satang: summary?.expense ?? 0,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.expense,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: theme.dividerColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.tr('รายจ่ายสะสมทั้งหมด', 'All-Time Expense'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AmountText(
                          satang: summary?.totalExpense ?? 0,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.tr('รายการรายจ่ายล่าสุด', 'Expense Transactions'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (expenseItems.isEmpty)
              PremiumCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      strings.tr('ยังไม่มีรายการรายจ่าย', 'No expense records yet'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              PremiumCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < expenseItems.length; i++) ...<Widget>[
                      if (i > 0)
                        const Divider(indent: 72, endIndent: 16, height: 1),
                      TransactionTile(
                        transaction: expenseItems[i],
                        showDate: true,
                        onTap: () => context.push(
                          '/transactions/${expenseItems[i].id}',
                          extra: expenseItems[i],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

