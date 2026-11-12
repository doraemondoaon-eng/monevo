import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../config/app_config.dart';

class PreferencesService {
  PreferencesService([this._prefs]);

  SharedPreferences? _prefs;

  static const String _keyThemeMode = 'monevo_theme_mode';
  static const String _keyLanguage = 'monevo_language';
  static const String _keyBuddhistEra = 'monevo_buddhist_era';
  static const String _keyPrivacyMode = 'monevo_privacy_mode';
  static const String _keyBiometricEnabled = 'monevo_biometric_enabled';
  static const String _keyAutoLockSeconds = 'monevo_auto_lock_seconds';

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<ThemeMode> getThemeMode() async {
    final SharedPreferences prefs = await _instance();
    final String? raw = prefs.getString(_keyThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_keyThemeMode, mode.name);
  }

  Future<AppLanguage> getLanguage() async {
    final SharedPreferences prefs = await _instance();
    return AppLanguage.fromCode(prefs.getString(_keyLanguage));
  }

  Future<void> setLanguage(AppLanguage language) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_keyLanguage, language.code);
  }

  Future<bool> getUseBuddhistEra() async {
    final SharedPreferences prefs = await _instance();
    return prefs.getBool(_keyBuddhistEra) ?? true;
  }

  Future<void> setUseBuddhistEra(bool value) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setBool(_keyBuddhistEra, value);
  }

  Future<bool> getPrivacyMode() async {
    final SharedPreferences prefs = await _instance();
    return prefs.getBool(_keyPrivacyMode) ?? false;
  }

  Future<void> setPrivacyMode(bool value) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setBool(_keyPrivacyMode, value);
  }

  Future<bool> getBiometricEnabled() async {
    final SharedPreferences prefs = await _instance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setBool(_keyBiometricEnabled, value);
  }

  Future<int> getAutoLockSeconds() async {
    final SharedPreferences prefs = await _instance();
    return prefs.getInt(_keyAutoLockSeconds) ??
        AppConfig.defaultAutoLockSeconds;
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setInt(_keyAutoLockSeconds, seconds);
  }
}

final Provider<PreferencesService> preferencesServiceProvider =
    Provider<PreferencesService>((Ref ref) {
      return PreferencesService();
    });
