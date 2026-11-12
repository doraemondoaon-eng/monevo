import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';

/// Section 8.2 Financial Analytics Screen (`/analytics`):
/// Dedicated financial analytics view presenting key metrics, cashflow ratios,
/// account balance distribution, and category breakdowns from real database data.
class FinancialAnalyticsScreen extends ConsumerWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashboardState state = ref.watch(dashboardControllerProvider);
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final DashboardSummary? summary = state.summary;
    final CategoryBreakdown? breakdown = state.categoryBreakdown;
    final AccountBalancesOverview? accountOverview =
        state.accountBalancesOverview;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.tr('วิเคราะห์สถานะทางการเงิน', 'Financial Analytics'),
        ),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            children: <Widget>[
              if (summary != null) ...<Widget>[
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.tr(
                          'สรุปอัตราส่วนทางการเงิน',
                          'Key Financial Ratios',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _KpiTile(
                              label: strings.tr(
                                'อัตราการออมเดือนนี้',
                                'Monthly Savings Rate',
                              ),
                              valueText: summary.savingsRate != null
                                  ? '${(summary.savingsRate! * 100).toStringAsFixed(1)}%'
                                  : '—',
                              valueColor: AppColors.primaryEmerald,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiTile(
                              label: strings.tr(
                                'กระแสเงินสดสุทธิ',
                                'Net Monthly Cashflow',
                              ),
                              satang: summary.net,
                              valueColor: summary.net >= 0
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _KpiTile(
                              label: strings.tr(
                                'รายรับสะสมทั้งหมด',
                                'All-Time Income',
                              ),
                              satang: summary.totalIncome,
                              valueColor: AppColors.income,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiTile(
                              label: strings.tr(
                                'รายจ่ายสะสมทั้งหมด',
                                'All-Time Expense',
                              ),
                              satang: summary.totalExpense,
                              valueColor: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (breakdown != null) ...<Widget>[
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            strings.categoryBreakdownTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SegmentedButton<String>(
                            segments: <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: 'expense',
                                label: Text(strings.expense),
                              ),
                              ButtonSegment<String>(
                                value: 'income',
                                label: Text(strings.income),
                              ),
                            ],
                            selected: <String>{state.categoryType},
                            onSelectionChanged: (Set<String> s) {
                              ref
                                  .read(dashboardControllerProvider.notifier)
                                  .setCategoryType(s.first);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (breakdown.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text(strings.noData)),
                        )
                      else
                        for (final CategoryBreakdownItem item
                            in breakdown.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '${item.name ?? strings.uncategorized} (${item.percentage.toStringAsFixed(1)}%)',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                AmountText(
                                  satang: item.amount,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (accountOverview != null)
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.tr(
                          'สัดส่วนยอดเงินแยกตามบัญชี',
                          'Account Balance Distribution',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final AccountBalanceOverviewItem acc
                          in accountOverview.accounts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '${acc.name} (${acc.sharePercent.toStringAsFixed(1)}%)',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              AmountText(
                                satang: acc.balance,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
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

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.valueColor,
    this.valueText,
    this.satang,
  });

  final String label;
  final Color valueColor;
  final String? valueText;
  final int? satang;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: valueColor.withAlpha(16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (satang != null)
            AmountText(
              satang: satang!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Text(
              valueText ?? '—',
              style: theme.textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

