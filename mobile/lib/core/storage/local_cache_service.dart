import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local Storage cache for offline-first read snapshots on the user's device.
/// PostgreSQL on the backend remains the single source of truth; this cache
/// provides instant startup rendering and graceful fallback if the network is slow.
class LocalCacheService {
  LocalCacheService([this._prefs]);

  SharedPreferences? _prefs;

  static const String _prefix = 'monevo_cache_v1_';
  static const String keyAccounts = '${_prefix}accounts';
  static const String keyCategories = '${_prefix}categories';
  static const String keyRecentTransactions = '${_prefix}recent_transactions';

  static String summaryKey(String month) => '${_prefix}summary_$month';

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> writeJsonList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final SharedPreferences prefs = await _instance();
      await prefs.setString(key, jsonEncode(items));
    } catch (_) {
      // Ignore local cache write failures; remote API is authoritative.
    }
  }

  Future<List<Map<String, dynamic>>?> readJsonList(String key) async {
    try {
      final SharedPreferences prefs = await _instance();
      final String? raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJsonMap(String key, Map<String, dynamic> data) async {
    try {
      final SharedPreferences prefs = await _instance();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // Ignore local cache write failures.
    }
  }

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    try {
      final SharedPreferences prefs = await _instance();
      final String? raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      final SharedPreferences prefs = await _instance();
      final List<String> keys = prefs
          .getKeys()
          .where((String k) => k.startsWith(_prefix))
          .toList();
      for (final String k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {
      // Ignore cache clear errors.
    }
  }
}

final Provider<LocalCacheService> localCacheServiceProvider =
    Provider<LocalCacheService>((Ref ref) {
      return LocalCacheService();
    });

