import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/sync/data_sync_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/transaction_form_sheet.dart';
import '../../transactions/presentation/transaction_tile.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashboardState state = ref.watch(dashboardControllerProvider);
    final DataSyncState syncState = ref.watch(dataSyncControllerProvider);
    final AppSettingsState settings = ref.watch(settingsControllerProvider);
    final AppLockState lockState = ref.watch(appLockControllerProvider);
    final String userName =
        ref.watch(authControllerProvider).user?.displayName ?? 'MONEVO';
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.appName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primaryEmerald,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              userName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ref.read(settingsControllerProvider.notifier).togglePrivacyMode();
            },
            tooltip: strings.privacyModeLabel,
            icon: Icon(
              settings.privacyMode
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          if (lockState.hasPin)
            IconButton(
              onPressed: () {
                ref.read(appLockControllerProvider.notifier).lockNow();
              },
              tooltip: strings.appLockedTitle,
              icon: const Icon(Icons.lock_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(dataSyncControllerProvider.notifier)
                .syncAllAndFlushOfflineQueue();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: <Widget>[
              // Section 13 Data Synchronization Status & Retry Bar
              _DataSyncStatusBanner(
                syncState: syncState,
                strings: strings,
                onSyncOrRetry: () {
                  ref
                      .read(dataSyncControllerProvider.notifier)
                      .syncAllAndFlushOfflineQueue();
                },
              ),
              const SizedBox(height: 10),
              // Month Selector Bar
              _MonthSelectorBar(
                selectedMonth: state.selectedMonth,
                language: strings.language,
                useBuddhistEra: settings.useBuddhistEra,
                onPrevious: () => ref
                    .read(dashboardControllerProvider.notifier)
                    .stepMonth(-1),
                onNext: () => ref
                    .read(dashboardControllerProvider.notifier)
                    .stepMonth(1),
              ),
              const SizedBox(height: 14),
              if (state.isLoading && state.summary == null) ...<Widget>[
                const SkeletonBox(height: 190, borderRadius: 24),
                const SizedBox(height: 16),
                const SkeletonBox(height: 150, borderRadius: 22),
                const SizedBox(height: 16),
                const SkeletonBox(height: 240, borderRadius: 22),
              ] else if (state.error != null && state.summary == null) ...<Widget>[
                ErrorStateView(
                  message: state.error!.localizedMessage(strings),
                  onRetry: () =>
                      ref.read(dashboardControllerProvider.notifier).refresh(),
                ),
              ] else ...<Widget>[
                if (state.summary != null) ...<Widget>[
                  _NetWorthHeroCard(
                    summary: state.summary!,
                    strings: strings,
                  ),
                  const SizedBox(height: 14),
                  _QuickActionsRow(strings: strings),
                  const SizedBox(height: 16),
                  _MonthlySummaryCard(
                    summary: state.summary!,
                    strings: strings,
                  ),
                  const SizedBox(height: 16),
                  _IncomeVsExpenseComparisonCard(
                    summary: state.summary!,
                    strings: strings,
                  ),
                  const SizedBox(height: 16),
                ],
                _CashflowChartCard(
                  granularity: state.cashflowGranularity,
                  dailyPoints: state.dailyCashflow,
                  dailyDays: state.dailyCashflowDays,
                  monthlyPoints: state.cashflow,
                  monthlyMonths: state.cashflowMonths,
                  yearlyPoints: state.yearlyCashflow,
                  yearlyYears: state.yearlyCashflowYears,
                  strings: strings,
                  useBuddhistEra: settings.useBuddhistEra,
                  onGranularityChanged: (CashflowGranularity g) {
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .setCashflowGranularity(g);
                  },
                  onDailyDaysChanged: (int days) {
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .setDailyCashflowDays(days);
                  },
                  onMonthlyMonthsChanged: (int months) {
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .setCashflowMonths(months);
                  },
                  onYearlyYearsChanged: (int years) {
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .setYearlyCashflowYears(years);
                  },
                ),
                const SizedBox(height: 16),
                _CategoryDonutCard(
                  breakdown: state.categoryBreakdown,
                  selectedType: state.categoryType,
                  strings: strings,
                  onTypeChanged: (String type) {
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .setCategoryType(type);
                  },
                ),
                const SizedBox(height: 16),
                if (state.accountBalancesOverview != null) ...<Widget>[
                  _AccountBalanceOverviewCard(
                    overview: state.accountBalancesOverview!,
                    strings: strings,
                  ),
                  const SizedBox(height: 16),
                ],
                _NetWorthTrendCard(
                  points: state.netWorthTrend,
                  selectedDays: state.trendDays,
                  strings: strings,
                  onDaysChanged: (int days) {
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .setTrendDays(days);
                  },
                ),
                const SizedBox(height: 16),
                _RecentTransactionsCard(
                  transactions: state.recentTransactions,
                  strings: strings,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSelectorBar extends StatelessWidget {
  const _MonthSelectorBar({
    required this.selectedMonth,
    required this.language,
    required this.useBuddhistEra,
    required this.onPrevious,
    required this.onNext,
  });

  final String selectedMonth;
  final AppLanguage language;
  final bool useBuddhistEra;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = AppDateUtils.formatMonthYear(
      selectedMonth,
      language: language,
      useBuddhistEra: useBuddhistEra,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        IconButton.filledTonal(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _NetWorthHeroCard extends StatelessWidget {
  const _NetWorthHeroCard({
    required this.summary,
    required this.strings,
  });

  final DashboardSummary summary;
  final AppStrings strings;

  String _financialStatusLabel() {
    switch (summary.financialStatus) {
      case 'excellent':
        return strings.tr('สถานะการเงิน: ดีเยี่ยม', 'Financial Status: Excellent');
      case 'good':
        return strings.tr('สถานะการเงิน: มั่นคง', 'Financial Status: Healthy');
      case 'warning':
        return strings.tr('สถานะการเงิน: ควรระวัง', 'Financial Status: Needs Attention');
      default:
        return strings.tr('สถานะการเงิน: ปานกลาง', 'Financial Status: Fair');
    }
  }

  Color _financialStatusColor() {
    switch (summary.financialStatus) {
      case 'excellent':
        return const Color(0xFF6EE7B7);
      case 'good':
        return const Color(0xFFA7F3D0);
      case 'warning':
        return const Color(0xFFFDA4AF);
      default:
        return const Color(0xFFFDE68A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor = _financialStatusColor();

    return PremiumCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                strings.netWorthTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.accountCount} ${strings.navAccounts}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AmountText(
            satang: summary.netWorth,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(34),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withAlpha(110)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.shield_outlined, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  _financialStatusLabel(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.tr('รายรับรวมทั้งหมด', 'Total Income'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withAlpha(190),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AmountText(
                        satang: summary.totalIncome,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.tr('รายจ่ายรวมทั้งหมด', 'Total Expense'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withAlpha(190),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AmountText(
                        satang: summary.totalExpense,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFFDA4AF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.totalAssets,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withAlpha(190),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AmountText(
                        satang: summary.totalAssets,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.totalLiabilities,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withAlpha(190),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AmountText(
                        satang: summary.totalLiabilities,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFFDA4AF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickActionChip(
            icon: Icons.south_west_rounded,
            label: strings.tr('รายรับ', 'Income'),
            color: AppColors.income,
            onTap: () => context.push('/income'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionChip(
            icon: Icons.north_east_rounded,
            label: strings.tr('รายจ่าย', 'Expense'),
            color: AppColors.expense,
            onTap: () => context.push('/expense'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionChip(
            icon: Icons.insights_rounded,
            label: strings.tr('วิเคราะห์', 'Analytics'),
            color: AppColors.primaryEmerald,
            onTap: () => context.push('/analytics'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionChip(
            icon: Icons.backup_outlined,
            label: strings.tr('สำรอง', 'Backup'),
            color: AppColors.transfer,
            onTap: () => context.push('/backup'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 16,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.summary,
    required this.strings,
  });

  final DashboardSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? savingsRate = summary.savingsRate;
    final String savingsText = savingsRate != null
        ? '${(savingsRate * 100).toStringAsFixed(1)}%'
        : '—';

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                strings.monthlyOverview,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${strings.savingsRate}: $savingsText',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryEmerald,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricColumn(
                  label: strings.income,
                  satang: summary.income,
                  prevSatang: summary.previousMonth.income,
                  color: AppColors.income,
                  icon: Icons.north_east_rounded,
                  strings: strings,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricColumn(
                  label: strings.expense,
                  satang: summary.expense,
                  prevSatang: summary.previousMonth.expense,
                  color: AppColors.expense,
                  icon: Icons.south_west_rounded,
                  strings: strings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                strings.netCashflow,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AmountText(
                satang: summary.net,
                showPlusSign: true,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: summary.net >= 0
                      ? AppColors.income
                      : AppColors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.satang,
    required this.prevSatang,
    required this.color,
    required this.icon,
    required this.strings,
  });

  final String label;
  final int satang;
  final int prevSatang;
  final Color color;
  final IconData icon;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AmountText(
            satang: satang,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text(
                '${strings.vsPreviousMonth}: ',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Flexible(
                child: AmountText(
                  satang: prevSatang,
                  compact: true,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeVsExpenseComparisonCard extends StatefulWidget {
  const _IncomeVsExpenseComparisonCard({
    required this.summary,
    required this.strings,
  });

  final DashboardSummary summary;
  final AppStrings strings;

  @override
  State<_IncomeVsExpenseComparisonCard> createState() =>
      _IncomeVsExpenseComparisonCardState();
}

class _IncomeVsExpenseComparisonCardState
    extends State<_IncomeVsExpenseComparisonCard> {
  bool _showAllTime = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int income = _showAllTime
        ? widget.summary.totalIncome
        : widget.summary.income;
    final int expense = _showAllTime
        ? widget.summary.totalExpense
        : widget.summary.expense;
    final int total = income + expense;
    final double incomeRatio = total > 0 ? income / total : 0.5;
    final double expenseRatio = total > 0 ? expense / total : 0.5;
    final int netDiff = income - expense;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.strings.tr(
                    'เปรียบเทียบรายรับ vs รายจ่าย',
                    'Income vs Expense Comparison',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SegmentedButton<bool>(
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(widget.strings.tr('เดือนนี้', 'Monthly')),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(widget.strings.tr('สะสมทั้งหมด', 'All-Time')),
                  ),
                ],
                selected: <bool>{_showAllTime},
                onSelectionChanged: (Set<bool> next) {
                  setState(() => _showAllTime = next.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 16,
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: math.max((incomeRatio * 1000).round(), 1),
                    child: Container(color: AppColors.income),
                  ),
                  Expanded(
                    flex: math.max((expenseRatio * 1000).round(), 1),
                    child: Container(color: AppColors.expense),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.income,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.strings.income} ${(total > 0 ? incomeRatio * 100 : 0).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.strings.expense} ${(total > 0 ? expenseRatio * 100 : 0).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                widget.strings.tr('ส่วนต่างสุทธิ', 'Net Difference'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AmountText(
                satang: netDiff,
                showPlusSign: true,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: netDiff >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashflowChartCard extends StatelessWidget {
  const _CashflowChartCard({
    required this.granularity,
    required this.dailyPoints,
    required this.dailyDays,
    required this.monthlyPoints,
    required this.monthlyMonths,
    required this.yearlyPoints,
    required this.yearlyYears,
    required this.strings,
    required this.useBuddhistEra,
    required this.onGranularityChanged,
    required this.onDailyDaysChanged,
    required this.onMonthlyMonthsChanged,
    required this.onYearlyYearsChanged,
  });

  final CashflowGranularity granularity;
  final List<DailyCashflowPoint> dailyPoints;
  final int dailyDays;
  final List<CashflowPoint> monthlyPoints;
  final int monthlyMonths;
  final List<YearlyCashflowPoint> yearlyPoints;
  final int yearlyYears;
  final AppStrings strings;
  final bool useBuddhistEra;
  final ValueChanged<CashflowGranularity> onGranularityChanged;
  final ValueChanged<int> onDailyDaysChanged;
  final ValueChanged<int> onMonthlyMonthsChanged;
  final ValueChanged<int> onYearlyYearsChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<({String label, int income, int expense})> series =
        <({String label, int income, int expense})>[];

    switch (granularity) {
      case CashflowGranularity.daily:
        for (final DailyCashflowPoint p in dailyPoints) {
          final List<String> parts = p.date.split('-');
          final String shortLabel = parts.length == 3
              ? '${parts[2]}/${parts[1]}'
              : p.date;
          series.add((
            label: shortLabel,
            income: p.income,
            expense: p.expense,
          ));
        }
      case CashflowGranularity.monthly:
        for (final CashflowPoint p in monthlyPoints) {
          final String formatted = AppDateUtils.formatMonthYear(
            p.month,
            language: strings.language,
            useBuddhistEra: useBuddhistEra,
            shortMonth: true,
          );
          series.add((
            label: formatted.split(' ').first,
            income: p.income,
            expense: p.expense,
          ));
        }
      case CashflowGranularity.yearly:
        for (final YearlyCashflowPoint p in yearlyPoints) {
          final int yr = int.tryParse(p.year) ?? 2026;
          final String label = useBuddhistEra ? '${yr + 543}' : p.year;
          series.add((
            label: label,
            income: p.income,
            expense: p.expense,
          ));
        }
    }

    int maxSatang = 100000;
    for (final ({String label, int income, int expense}) item in series) {
      maxSatang = math.max(maxSatang, math.max(item.income, item.expense));
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.tr(
                    'กราฟรายรับ-รายจ่าย (รายวัน/เดือน/ปี)',
                    'Income & Expense Analytics',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (granularity == CashflowGranularity.daily)
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 7, label: Text('7D')),
                    ButtonSegment<int>(value: 14, label: Text('14D')),
                    ButtonSegment<int>(value: 30, label: Text('30D')),
                  ],
                  selected: <int>{dailyDays},
                  onSelectionChanged: (Set<int> s) =>
                      onDailyDaysChanged(s.first),
                )
              else if (granularity == CashflowGranularity.monthly)
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 3, label: Text('3M')),
                    ButtonSegment<int>(value: 6, label: Text('6M')),
                    ButtonSegment<int>(value: 12, label: Text('12M')),
                  ],
                  selected: <int>{monthlyMonths},
                  onSelectionChanged: (Set<int> s) =>
                      onMonthlyMonthsChanged(s.first),
                )
              else
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 3, label: Text('3Y')),
                    ButtonSegment<int>(value: 5, label: Text('5Y')),
                  ],
                  selected: <int>{yearlyYears},
                  onSelectionChanged: (Set<int> s) =>
                      onYearlyYearsChanged(s.first),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<CashflowGranularity>(
            segments: <ButtonSegment<CashflowGranularity>>[
              ButtonSegment<CashflowGranularity>(
                value: CashflowGranularity.daily,
                label: Text(strings.tr('รายวัน', 'Daily')),
              ),
              ButtonSegment<CashflowGranularity>(
                value: CashflowGranularity.monthly,
                label: Text(strings.tr('รายเดือน', 'Monthly')),
              ),
              ButtonSegment<CashflowGranularity>(
                value: CashflowGranularity.yearly,
                label: Text(strings.tr('รายปี', 'Yearly')),
              ),
            ],
            selected: <CashflowGranularity>{granularity},
            onSelectionChanged: (Set<CashflowGranularity> s) =>
                onGranularityChanged(s.first),
          ),
          const SizedBox(height: 18),
          if (series.isEmpty)
            SizedBox(
              height: 180,
              child: Center(child: Text(strings.noData)),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: (maxSatang / 100.0) * 1.2,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 54,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              MoneyUtils.formatCompactSatang(
                                (value * 100).round(),
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int idx = value.toInt();
                          if (idx < 0 || idx >= series.length) {
                            return const SizedBox.shrink();
                          }
                          final int step = series.length > 10 ? 3 : 1;
                          if (idx % step != 0 && idx != series.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              series[idx].label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List<BarChartGroupData>.generate(
                    series.length,
                    (int index) {
                      final ({String label, int income, int expense}) p =
                          series[index];
                      final double rodWidth = series.length > 14 ? 5 : 9;
                      return BarChartGroupData(
                        x: index,
                        barsSpace: 3,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: p.income / 100.0,
                            color: AppColors.income,
                            width: rodWidth,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: p.expense / 100.0,
                            color: AppColors.expense,
                            width: rodWidth,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({
    required this.breakdown,
    required this.selectedType,
    required this.strings,
    required this.onTypeChanged,
  });

  final CategoryBreakdown? breakdown;
  final String selectedType;
  final AppStrings strings;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<CategoryBreakdownItem> items =
        breakdown?.items ?? <CategoryBreakdownItem>[];

    return PremiumCard(
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
                selected: <String>{selectedType},
                onSelectionChanged: (Set<String> s) => onTypeChanged(s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  strings.noData,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...<Widget>[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 46,
                  sections: items.map((CategoryBreakdownItem item) {
                    final Color color = AppColors.fromHex(item.color);
                    return PieChartSectionData(
                      value: math.max(item.amount.toDouble(), 1.0),
                      color: color,
                      radius: 34,
                      showTitle: item.percentage >= 10,
                      title: '${item.percentage.round()}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final CategoryBreakdownItem item in items.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.fromHex(item.color).withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        IconMapper.resolve(item.icon),
                        color: AppColors.fromHex(item.color),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name ?? strings.uncategorized,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${item.percentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
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
        ],
      ),
    );
  }
}

class _AccountBalanceOverviewCard extends StatelessWidget {
  const _AccountBalanceOverviewCard({
    required this.overview,
    required this.strings,
  });

  final AccountBalancesOverview overview;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AccountBalanceOverviewItem> items = overview.accounts;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                strings.tr(
                  'ภาพรวมยอดคงเหลือรายบัญชี',
                  'Account Balance Overview',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/accounts'),
                child: Text(strings.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text(strings.noData)),
            )
          else
            for (final AccountBalanceOverviewItem acc in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.fromHex(acc.color).withAlpha(28),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            IconMapper.resolve(acc.icon),
                            size: 16,
                            color: AppColors.fromHex(acc.color),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            acc.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${acc.sharePercent.toStringAsFixed(1)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        AmountText(
                          satang: acc.balance,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: acc.balance >= 0
                                ? null
                                : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (acc.sharePercent / 100.0).clamp(0.0, 1.0),
                        minHeight: 7,
                        color: AppColors.fromHex(acc.color),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _NetWorthTrendCard extends StatelessWidget {
  const _NetWorthTrendCard({
    required this.points,
    required this.selectedDays,
    required this.strings,
    required this.onDaysChanged,
  });

  final List<NetWorthPoint> points;
  final int selectedDays;
  final AppStrings strings;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<FlSpot> spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].netWorth / 100.0));
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.netWorthTrendTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 7, label: Text('7D')),
                  ButtonSegment<int>(value: 30, label: Text('30D')),
                  ButtonSegment<int>(value: 90, label: Text('90D')),
                  ButtonSegment<int>(value: 365, label: Text('365D')),
                ],
                selected: <int>{selectedDays},
                onSelectionChanged: (Set<int> s) => onDaysChanged(s.first),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (spots.isEmpty)
            SizedBox(
              height: 160,
              child: Center(child: Text(strings.noData)),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 54,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              MoneyUtils.formatCompactSatang(
                                (value * 100).round(),
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: AppColors.primaryEmerald,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primaryEmerald.withAlpha(32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.transactions,
    required this.strings,
  });

  final List<TransactionModel> transactions;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  strings.recentTransactionsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: Text(strings.viewAll),
                ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  strings.noData,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (int i = 0; i < transactions.length; i++) ...<Widget>[
              if (i > 0) const Divider(indent: 72, endIndent: 16, height: 1),
              TransactionTile(
                transaction: transactions[i],
                showDate: true,
                onTap: () {
                  context.push(
                    '/transactions/${transactions[i].id}',
                    extra: transactions[i],
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

class _DataSyncStatusBanner extends StatelessWidget {
  const _DataSyncStatusBanner({
    required this.syncState,
    required this.strings,
    required this.onSyncOrRetry,
  });

  final DataSyncState syncState;
  final AppStrings strings;
  final VoidCallback onSyncOrRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (syncState.stage) {
      case SyncStage.syncing:
        statusColor = AppColors.transfer;
        statusIcon = Icons.sync_rounded;
        statusText = strings.tr(
          'กำลังซิงก์ข้อมูลการเงินกับ Cloud...',
          'Syncing financial data with Cloud...',
        );
        break;
      case SyncStage.offlinePending:
        statusColor = AppColors.warning;
        statusIcon = Icons.cloud_off_rounded;
        statusText = strings.tr(
          'ออฟไลน์ · บันทึกในเครื่องแล้ว รอซิงก์ ${syncState.pendingCount} รายการ',
          'Offline · Saved locally, ${syncState.pendingCount} pending sync',
        );
        break;
      case SyncStage.syncError:
        statusColor = AppColors.expense;
        statusIcon = Icons.error_outline_rounded;
        statusText = strings.tr(
          'ซิงก์ไม่สำเร็จ · ข้อมูลในเครื่องปลอดภัย กดลองใหม่ได้',
          'Sync failed · Local data is safe, tap to retry',
        );
        break;
      case SyncStage.synced:
        statusColor = AppColors.income;
        statusIcon = Icons.cloud_done_outlined;
        final String timeLabel = syncState.lastSyncedAt != null
            ? AppDateUtils.formatTimeOnly(syncState.lastSyncedAt!)
            : '';
        statusText = strings.tr(
          'ซิงก์ข้อมูลการเงินแล้ว${timeLabel.isNotEmpty ? ' ($timeLabel)' : ''} · รูปสลิปเก็บเฉพาะในเครื่อง',
          'Financial data synced${timeLabel.isNotEmpty ? ' ($timeLabel)' : ''} · Images stored on device only',
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withAlpha(55)),
      ),
      child: Row(
        children: <Widget>[
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!syncState.isSyncing)
            InkWell(
              onTap: onSyncOrRetry,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  syncState.stage == SyncStage.synced
                      ? strings.tr('ซิงก์', 'Sync')
                      : strings.tr('ลองใหม่', 'Retry'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
