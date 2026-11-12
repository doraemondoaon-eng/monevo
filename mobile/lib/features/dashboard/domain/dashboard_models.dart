class PreviousMonthTotals {
  const PreviousMonthTotals({
    required this.income,
    required this.expense,
  });

  factory PreviousMonthTotals.fromJson(Map<String, dynamic> json) {
    return PreviousMonthTotals(
      income: (json['income'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toInt() ?? 0,
    );
  }

  final int income;
  final int expense;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'income': income,
    'expense': expense,
  };
}

class DashboardSummary {
  const DashboardSummary({
    required this.month,
    required this.currency,
    required this.netWorth,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.income,
    required this.expense,
    required this.net,
    required this.savingsRate,
    required this.previousMonth,
    required this.accountCount,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.financialStatus = 'good',
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final int monthlyIncome = (json['income'] as num?)?.toInt() ?? 0;
    final int monthlyExpense = (json['expense'] as num?)?.toInt() ?? 0;
    return DashboardSummary(
      month: (json['month'] ?? '').toString(),
      currency: (json['currency'] ?? 'THB').toString(),
      netWorth: (json['netWorth'] as num?)?.toInt() ?? 0,
      totalAssets: (json['totalAssets'] as num?)?.toInt() ?? 0,
      totalLiabilities: (json['totalLiabilities'] as num?)?.toInt() ?? 0,
      totalIncome: (json['totalIncome'] as num?)?.toInt() ?? monthlyIncome,
      totalExpense: (json['totalExpense'] as num?)?.toInt() ?? monthlyExpense,
      income: monthlyIncome,
      expense: monthlyExpense,
      net: (json['net'] as num?)?.toInt() ?? 0,
      savingsRate: (json['savingsRate'] as num?)?.toDouble(),
      financialStatus: (json['financialStatus'] ?? 'good').toString(),
      previousMonth: PreviousMonthTotals.fromJson(
        (json['previousMonth'] as Map<String, dynamic>?) ??
            <String, dynamic>{},
      ),
      accountCount: (json['accountCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String month;
  final String currency;
  final int netWorth;
  final int totalAssets;
  final int totalLiabilities;
  final int totalIncome;
  final int totalExpense;
  final int income;
  final int expense;
  final int net;
  final double? savingsRate;
  final String financialStatus;
  final PreviousMonthTotals previousMonth;
  final int accountCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'month': month,
    'currency': currency,
    'netWorth': netWorth,
    'totalAssets': totalAssets,
    'totalLiabilities': totalLiabilities,
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
    'income': income,
    'expense': expense,
    'net': net,
    'savingsRate': savingsRate,
    'financialStatus': financialStatus,
    'previousMonth': previousMonth.toJson(),
    'accountCount': accountCount,
  };
}

class CashflowPoint {
  const CashflowPoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.net,
  });

  factory CashflowPoint.fromJson(Map<String, dynamic> json) {
    return CashflowPoint(
      month: (json['month'] ?? '').toString(),
      income: (json['income'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toInt() ?? 0,
      net: (json['net'] as num?)?.toInt() ?? 0,
    );
  }

  final String month;
  final int income;
  final int expense;
  final int net;
}

class DailyCashflowPoint {
  const DailyCashflowPoint({
    required this.date,
    required this.income,
    required this.expense,
    required this.net,
  });

  factory DailyCashflowPoint.fromJson(Map<String, dynamic> json) {
    return DailyCashflowPoint(
      date: (json['date'] ?? '').toString(),
      income: (json['income'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toInt() ?? 0,
      net: (json['net'] as num?)?.toInt() ?? 0,
    );
  }

  final String date;
  final int income;
  final int expense;
  final int net;
}

class YearlyCashflowPoint {
  const YearlyCashflowPoint({
    required this.year,
    required this.income,
    required this.expense,
    required this.net,
  });

  factory YearlyCashflowPoint.fromJson(Map<String, dynamic> json) {
    return YearlyCashflowPoint(
      year: (json['year'] ?? '').toString(),
      income: (json['income'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toInt() ?? 0,
      net: (json['net'] as num?)?.toInt() ?? 0,
    );
  }

  final String year;
  final int income;
  final int expense;
  final int net;
}

class AccountBalanceOverviewItem {
  const AccountBalanceOverviewItem({
    required this.id,
    required this.name,
    required this.type,
    required this.institution,
    required this.color,
    required this.icon,
    required this.balance,
    required this.includeInNetWorth,
    required this.sharePercent,
  });

  factory AccountBalanceOverviewItem.fromJson(Map<String, dynamic> json) {
    return AccountBalanceOverviewItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'bank').toString(),
      institution: json['institution']?.toString(),
      color: (json['color'] ?? '#0D9488').toString(),
      icon: (json['icon'] ?? 'account_balance').toString(),
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      includeInNetWorth: json['includeInNetWorth'] != false,
      sharePercent: (json['sharePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String id;
  final String name;
  final String type;
  final String? institution;
  final String color;
  final String icon;
  final int balance;
  final bool includeInNetWorth;
  final double sharePercent;
}

class AccountBalancesOverview {
  const AccountBalancesOverview({
    required this.currency,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.accounts,
  });

  factory AccountBalancesOverview.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawAccounts =
        (json['accounts'] as List<dynamic>?) ?? <dynamic>[];
    return AccountBalancesOverview(
      currency: (json['currency'] ?? 'THB').toString(),
      totalAssets: (json['totalAssets'] as num?)?.toInt() ?? 0,
      totalLiabilities: (json['totalLiabilities'] as num?)?.toInt() ?? 0,
      netWorth: (json['netWorth'] as num?)?.toInt() ?? 0,
      accounts: rawAccounts
          .whereType<Map<String, dynamic>>()
          .map(AccountBalanceOverviewItem.fromJson)
          .toList(),
    );
  }

  final String currency;
  final int totalAssets;
  final int totalLiabilities;
  final int netWorth;
  final List<AccountBalanceOverviewItem> accounts;
}

class CategoryBreakdownItem {
  const CategoryBreakdownItem({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.count,
  });

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      categoryId: json['categoryId']?.toString(),
      name: json['name']?.toString(),
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  final String? categoryId;
  final String? name;
  final String? icon;
  final String? color;
  final int amount;
  final double percentage;
  final int count;
}

class CategoryBreakdown {
  const CategoryBreakdown({
    required this.month,
    required this.type,
    required this.total,
    required this.items,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems =
        (json['items'] as List<dynamic>?) ?? <dynamic>[];
    return CategoryBreakdown(
      month: (json['month'] ?? '').toString(),
      type: (json['type'] ?? 'expense').toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(CategoryBreakdownItem.fromJson)
          .toList(),
    );
  }

  final String month;
  final String type;
  final int total;
  final List<CategoryBreakdownItem> items;
}

class NetWorthPoint {
  const NetWorthPoint({
    required this.date,
    required this.netWorth,
  });

  factory NetWorthPoint.fromJson(Map<String, dynamic> json) {
    return NetWorthPoint(
      date: (json['date'] ?? '').toString(),
      netWorth: (json['netWorth'] as num?)?.toInt() ?? 0,
    );
  }

  final String date;
  final int netWorth;
}
