import '../../../l10n/app_strings.dart';

enum AccountType {
  bank('bank', 'account_balance', '#0D9488'),
  cash('cash', 'payments', '#10B981'),
  creditCard('credit_card', 'credit_card', '#F43F5E'),
  eWallet('e_wallet', 'phone_android', '#3B82F6'),
  investment('investment', 'trending_up', '#8B5CF6'),
  other('other', 'wallet', '#64748B');

  const AccountType(this.apiValue, this.defaultIcon, this.defaultColor);

  final String apiValue;
  final String defaultIcon;
  final String defaultColor;

  static AccountType fromApi(String? raw) {
    for (final AccountType t in AccountType.values) {
      if (t.apiValue == raw) {
        return t;
      }
    }
    return AccountType.other;
  }

  String label(AppStrings strings) {
    switch (this) {
      case AccountType.bank:
        return strings.tr('บัญชีธนาคาร', 'Bank Account');
      case AccountType.cash:
        return strings.tr('เงินสด', 'Cash');
      case AccountType.creditCard:
        return strings.tr('บัตรเครดิต', 'Credit Card');
      case AccountType.eWallet:
        return strings.tr('อีวอลเล็ท (e-Wallet)', 'e-Wallet');
      case AccountType.investment:
        return strings.tr('การลงทุน', 'Investment');
      case AccountType.other:
        return strings.tr('อื่นๆ', 'Other');
    }
  }
}

class AccountModel {
  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.institution,
    required this.accountNumberLast4,
    required this.currency,
    required this.openingBalance,
    required this.balance,
    required this.color,
    required this.icon,
    required this.includeInNetWorth,
    required this.isArchived,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    final AccountType parsedType = AccountType.fromApi(
      json['type']?.toString(),
    );
    return AccountModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: parsedType,
      institution: json['institution']?.toString(),
      accountNumberLast4: json['accountNumberLast4']?.toString(),
      currency: (json['currency'] ?? 'THB').toString(),
      openingBalance: (json['openingBalance'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      color: (json['color'] ?? parsedType.defaultColor).toString(),
      icon: (json['icon'] ?? parsedType.defaultIcon).toString(),
      includeInNetWorth: json['includeInNetWorth'] != false,
      isArchived: json['isArchived'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final AccountType type;
  final String? institution;
  final String? accountNumberLast4;
  final String currency;
  final int openingBalance;
  final int balance;
  final String color;
  final String icon;
  final bool includeInNetWorth;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get subtitle {
    final List<String> parts = <String>[];
    if (institution != null && institution!.trim().isNotEmpty) {
      parts.add(institution!.trim());
    }
    if (accountNumberLast4 != null && accountNumberLast4!.trim().isNotEmpty) {
      parts.add('•••• ${accountNumberLast4!.trim()}');
    }
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.apiValue,
      'institution': institution,
      'accountNumberLast4': accountNumberLast4,
      'currency': currency,
      'openingBalance': openingBalance,
      'balance': balance,
      'color': color,
      'icon': icon,
      'includeInNetWorth': includeInNetWorth,
      'isArchived': isArchived,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  AccountModel copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? institution,
    String? accountNumberLast4,
    String? currency,
    int? openingBalance,
    int? balance,
    String? color,
    String? icon,
    bool? includeInNetWorth,
    bool? isArchived,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      institution: institution ?? this.institution,
      accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      balance: balance ?? this.balance,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
