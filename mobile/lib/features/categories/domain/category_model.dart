import '../../../l10n/app_strings.dart';

enum CategoryType {
  expense('expense'),
  income('income');

  const CategoryType(this.apiValue);
  final String apiValue;

  static CategoryType fromApi(String? raw) {
    if (raw == 'income') {
      return CategoryType.income;
    }
    return CategoryType.expense;
  }

  String label(AppStrings strings) {
    switch (this) {
      case CategoryType.income:
        return strings.income;
      case CategoryType.expense:
        return strings.expense;
    }
  }
}

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isArchived,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: CategoryType.fromApi(json['type']?.toString()),
      icon: (json['icon'] ?? 'more_horiz').toString(),
      color: (json['color'] ?? '#0D9488').toString(),
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
  final CategoryType type;
  final String icon;
  final String color;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.apiValue,
      'icon': icon,
      'color': color,
      'isArchived': isArchived,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    CategoryType? type,
    String? icon,
    String? color,
    bool? isArchived,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
