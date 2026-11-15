import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../domain/transaction_model.dart';
import 'transaction_form_sheet.dart';
import 'transaction_tile.dart';
import 'transactions_controller.dart';

/// Dedicated view for managing account-to-account transfer records,
/// monthly vs all-time transfer totals, and quick transfer creation.
class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  Future<void> _openAddTransfer(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const TransactionFormSheet(
        initialType: TransactionType.transfer,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final TransactionsState txState = ref.watch(transactionsControllerProvider);
    final List<TransactionModel> transferItems = txState.items
        .where((TransactionModel t) => t.type == TransactionType.transfer)
        .toList();

    final String currentMonth = AppDateUtils.toApiMonth(DateTime.now());
    int monthlyTransfer = 0;
    int totalTransfer = 0;
    for (final TransactionModel tx in transferItems) {
      totalTransfer += tx.amount;
      if (AppDateUtils.toApiMonth(tx.occurredAt.toLocal()) == currentMonth) {
        monthlyTransfer += tx.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.tr('จัดการโอนเงิน', 'Transfer Management')),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openAddTransfer(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: strings.tr('เพิ่มรายการโอน', 'Add Transfer'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTransfer(context),
        backgroundColor: AppColors.transfer,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          strings.tr('บันทึกโอนเงิน', 'Record Transfer'),
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
                          strings.tr('ยอดโอนประจำเดือน', 'Monthly Transfer'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AmountText(
                          satang: monthlyTransfer,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.transfer,
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
                          strings.tr('ยอดโอนสะสมทั้งหมด', 'All-Time Transfer'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AmountText(
                          satang: totalTransfer,
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
              strings.tr('รายการโอนล่าสุด', 'Transfer Transactions'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (transferItems.isEmpty)
              PremiumCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      strings.tr('ยังไม่มีรายการโอน', 'No transfer records yet'),
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
                    for (int i = 0; i < transferItems.length; i++) ...<Widget>[
                      if (i > 0)
                        const Divider(indent: 72, endIndent: 16, height: 1),
                      TransactionTile(
                        transaction: transferItems[i],
                        showDate: true,
                        onTap: () => context.push(
                          '/transactions/${transferItems[i].id}',
                          extra: transferItems[i],
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
