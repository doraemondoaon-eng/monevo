import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_service.dart';
import '../../../l10n/app_strings.dart';

class AppSettingsState {
  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.th,
    this.useBuddhistEra = true,
    this.privacyMode = false,
    this.loaded = false,
  });

  final ThemeMode themeMode;
  final AppLanguage language;
  final bool useBuddhistEra;
  final bool privacyMode;
  final bool loaded;

  AppStrings get strings => AppStrings(language);

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? useBuddhistEra,
    bool? privacyMode,
    bool? loaded,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      useBuddhistEra: useBuddhistEra ?? this.useBuddhistEra,
      privacyMode: privacyMode ?? this.privacyMode,
      loaded: loaded ?? this.loaded,
    );
  }
}

class SettingsController extends StateNotifier<AppSettingsState> {
  SettingsController(this._preferences) : super(const AppSettingsState()) {
    load();
  }

  final PreferencesService _preferences;

  Future<void> load() async {
    final ThemeMode themeMode = await _preferences.getThemeMode();
    final AppLanguage language = await _preferences.getLanguage();
    final bool useBuddhistEra = await _preferences.getUseBuddhistEra();
    final bool privacyMode = await _preferences.getPrivacyMode();

    state = state.copyWith(
      themeMode: themeMode,
      language: language,
      useBuddhistEra: useBuddhistEra,
      privacyMode: privacyMode,
      loaded: true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _preferences.setThemeMode(mode);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    await _preferences.setLanguage(language);
  }

  Future<void> setUseBuddhistEra(bool value) async {
    state = state.copyWith(useBuddhistEra: value);
    await _preferences.setUseBuddhistEra(value);
  }

  Future<void> togglePrivacyMode() async {
    final bool next = !state.privacyMode;
    state = state.copyWith(privacyMode: next);
    await _preferences.setPrivacyMode(next);
  }

  Future<void> setPrivacyMode(bool value) async {
    state = state.copyWith(privacyMode: value);
    await _preferences.setPrivacyMode(value);
  }
}

final StateNotifierProvider<SettingsController, AppSettingsState>
settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettingsState>((Ref ref) {
      return SettingsController(ref.watch(preferencesServiceProvider));
    });
