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

/// Section 8.2 Income Screen (`/income`):
/// Dedicated view for managing all income records, monthly vs all-time income
/// summary, and quick income creation.
class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  Future<void> _openAddIncome(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const TransactionFormSheet(
        initialType: TransactionType.income,
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
    final List<TransactionModel> incomeItems = txState.items
        .where((TransactionModel t) => t.type == TransactionType.income)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('จัดการรายรับ', 'Income Management')),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openAddIncome(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: strings.tr('เพิ่มรายรับ', 'Add Income'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddIncome(context),
        backgroundColor: AppColors.income,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          strings.tr('บันทึกรายรับ', 'Record Income'),
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
                          strings.tr('รายรับประจำเดือน', 'Monthly Income'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AmountText(
                          satang: summary?.income ?? 0,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.income,
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
                          strings.tr('รายรับสะสมทั้งหมด', 'All-Time Income'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AmountText(
                          satang: summary?.totalIncome ?? 0,
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
              strings.tr('รายการรายรับล่าสุด', 'Income Transactions'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (incomeItems.isEmpty)
              PremiumCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      strings.tr('ยังไม่มีรายการรายรับ', 'No income records yet'),
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
                    for (int i = 0; i < incomeItems.length; i++) ...<Widget>[
                      if (i > 0)
                        const Divider(indent: 72, endIndent: 16, height: 1),
                      TransactionTile(
                        transaction: incomeItems[i],
                        showDate: true,
                        onTap: () => context.push(
                          '/transactions/${incomeItems[i].id}',
                          extra: incomeItems[i],
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

