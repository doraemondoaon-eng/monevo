import 'package:flutter/material.dart';

class IconMapper {
  const IconMapper._();

  static const Map<String, IconData> _iconMap = <String, IconData>{
    'wallet': Icons.account_balance_wallet_rounded,
    'account_balance': Icons.account_balance_rounded,
    'payments': Icons.payments_rounded,
    'credit_card': Icons.credit_card_rounded,
    'savings': Icons.savings_rounded,
    'trending_up': Icons.trending_up_rounded,
    'phone_android': Icons.phone_android_rounded,
    'restaurant': Icons.restaurant_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'local_grocery_store': Icons.local_grocery_store_rounded,
    'directions_car': Icons.directions_car_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'flight': Icons.flight_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'home': Icons.home_rounded,
    'bolt': Icons.bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'wifi': Icons.wifi_rounded,
    'medical_services': Icons.medical_services_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'movie': Icons.movie_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'school': Icons.school_rounded,
    'shield': Icons.shield_rounded,
    'pets': Icons.pets_rounded,
    'child_care': Icons.child_care_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'volunteer_activism': Icons.volunteer_activism_rounded,
    'work': Icons.work_rounded,
    'star': Icons.star_rounded,
    'store': Icons.store_rounded,
    'percent': Icons.percent_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'more_horiz': Icons.more_horiz_rounded,
  };

  /// All valid `IconKey` values defined in `API.md`.
  static List<String> get allKeys => _iconMap.keys.toList(growable: false);

  /// Maps an API `IconKey` string to a Material [IconData].
  /// Unknown or null keys fall back to `more_horiz` per API contract.
  static IconData resolve(String? key) {
    if (key == null || key.isEmpty) {
      return Icons.more_horiz_rounded;
    }
    return _iconMap[key] ?? Icons.more_horiz_rounded;
  }
}
