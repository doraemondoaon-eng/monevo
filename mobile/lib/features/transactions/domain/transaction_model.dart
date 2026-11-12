import '../../../l10n/app_strings.dart';

enum TransactionType {
  expense('expense'),
  income('income'),
  transfer('transfer');

  const TransactionType(this.apiValue);
  final String apiValue;

  static TransactionType fromApi(String? raw) {
    switch (raw) {
      case 'income':
        return TransactionType.income;
      case 'transfer':
        return TransactionType.transfer;
      default:
        return TransactionType.expense;
    }
  }

  String label(AppStrings strings) {
    switch (this) {
      case TransactionType.income:
        return strings.income;
      case TransactionType.expense:
        return strings.expense;
      case TransactionType.transfer:
        return strings.transfer;
    }
  }
}

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.occurredAt,
    required this.payee,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: (json['id'] ?? '').toString(),
      type: TransactionType.fromApi(json['type']?.toString()),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] ?? 'THB').toString(),
      accountId: (json['accountId'] ?? '').toString(),
      toAccountId: json['toAccountId']?.toString(),
      categoryId: json['categoryId']?.toString(),
      occurredAt:
          DateTime.tryParse((json['occurredAt'] ?? '').toString()) ??
          DateTime.now(),
      payee: json['payee']?.toString(),
      note: json['note']?.toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final TransactionType type;
  final int amount;
  final String currency;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final DateTime occurredAt;
  final String? payee;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.apiValue,
      'amount': amount,
      'currency': currency,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'categoryId': categoryId,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'payee': payee,
      'note': note,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  TransactionModel copyWith({
    String? id,
    TransactionType? type,
    int? amount,
    String? currency,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    DateTime? occurredAt,
    String? payee,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      occurredAt: occurredAt ?? this.occurredAt,
      payee: payee ?? this.payee,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PaginatedTransactions {
  const PaginatedTransactions({
    required this.items,
    required this.nextCursor,
  });

  factory PaginatedTransactions.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawList =
        (json['data'] as List<dynamic>?) ?? <dynamic>[];
    return PaginatedTransactions(
      items: rawList
          .whereType<Map<String, dynamic>>()
          .map(TransactionModel.fromJson)
          .toList(),
      nextCursor: json['nextCursor']?.toString(),
    );
  }

  final List<TransactionModel> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

class TransactionFilter {
  const TransactionFilter({
    this.type,
    this.accountId,
    this.categoryId,
    this.from,
    this.to,
    this.query = '',
  });

  final TransactionType? type;
  final String? accountId;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;
  final String query;

  bool get hasActiveFilters =>
      type != null ||
      accountId != null ||
      categoryId != null ||
      from != null ||
      to != null ||
      query.trim().isNotEmpty;

  TransactionFilter copyWith({
    TransactionType? type,
    bool clearType = false,
    String? accountId,
    bool clearAccountId = false,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? query,
  }) {
    return TransactionFilter(
      type: clearType ? null : (type ?? this.type),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      query: query ?? this.query,
    );
  }
}
