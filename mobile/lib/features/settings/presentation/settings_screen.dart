import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/update/app_update_dialog.dart';
import '../../../core/update/app_update_service.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lock/presentation/pin_setup_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    User user,
    AppStrings strings,
  ) async {
    final TextEditingController nameCtrl = TextEditingController(
      text: user.displayName,
    );
    final TextEditingController tzCtrl = TextEditingController(
      text: user.timezone,
    );

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(strings.profileSection),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: strings.displayNameLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tzCtrl,
                decoration: const InputDecoration(
                  labelText: 'Timezone',
                  hintText: 'Asia/Bangkok',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(strings.save),
            ),
          ],
        );
      },
    );

    if (shouldSave == true && context.mounted) {
      try {
        await ref
            .read(authControllerProvider.notifier)
            .updateProfile(
              displayName: nameCtrl.text.trim(),
              timezone: tzCtrl.text.trim(),
            );
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.localizedMessage(strings))),
          );
        }
      }
    }
    nameCtrl.dispose();
    tzCtrl.dispose();
  }

  Future<void> _checkForUpdatesManually(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final AppUpdateService service = ref.read(appUpdateServiceProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          strings.tr('กำลังตรวจสอบอัปเดต...', 'Checking for updates...'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    final AppUpdateCheckResult result = await service.checkForUpdate(
      silent: false,
    );
    if (!context.mounted) {
      return;
    }
    messenger.hideCurrentSnackBar();
    if (result.hasUpdate && result.updateInfo != null) {
      await AppUpdateDialog.show(
        context,
        info: result.updateInfo!,
        service: service,
      );
      return;
    }
    if (result.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            strings.tr(
              'ยังตรวจสอบอัปเดตไม่ได้ (ตรวจสอบอินเทอร์เน็ตหรือการเปิด Public ของคลัง)',
              'Could not check for updates right now.',
            ),
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          strings.tr(
            'คุณใช้เวอร์ชันล่าสุดอยู่แล้ว (v${AppConfig.appVersion})',
            'You are already on the latest version (v${AppConfig.appVersion}).',
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final TextEditingController currentCtrl = TextEditingController();
    final TextEditingController newCtrl = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(strings.changePasswordLabel),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: strings.tr(
                      'รหัสผ่านปัจจุบัน',
                      'Current Password',
                    ),
                  ),
                  validator: (String? v) => (v == null || v.isEmpty)
                      ? strings.tr('กรุณากรอกรหัสผ่าน', 'Required')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: strings.tr(
                      'รหัสผ่านใหม่ (อย่างน้อย 10 ตัวอักษร)',
                      'New Password (min 10 chars)',
                    ),
                  ),
                  validator: (String? v) => (v == null || v.length < 10)
                      ? strings.passwordHintMin10
                      : null,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: Text(strings.save),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(authControllerProvider.notifier)
            .changePassword(
              currentPassword: currentCtrl.text,
              newPassword: newCtrl.text,
            );
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.localizedMessage(strings))),
          );
        }
      }
    }
    currentCtrl.dispose();
    newCtrl.dispose();
  }

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(strings.logoutButton),
          content: Text(strings.logoutConfirm),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              child: Text(strings.logoutButton),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(authControllerProvider).user;
    final AppSettingsState settings = ref.watch(settingsControllerProvider);
    final AppLockState lockState = ref.watch(appLockControllerProvider);
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.navSettings)),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: <Widget>[
            // Owner Profile Card
            if (user != null) ...<Widget>[
              PremiumCard(
                onTap: () => _showEditProfileDialog(
                  context,
                  ref,
                  user,
                  strings,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            AppColors.heroStart,
                            AppColors.primaryEmerald,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName.characters.first.toUpperCase()
                              : 'M',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.baseCurrency} · ${user.timezone}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryEmerald,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Categories & Local Backup Management
            _SectionHeader(title: strings.dataManagementSection),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(
                      Icons.category_outlined,
                      color: AppColors.primaryEmerald,
                    ),
                    title: Text(
                      strings.categoriesTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/categories'),
                  ),
                  const Divider(indent: 56, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.backup_outlined,
                      color: AppColors.primaryEmerald,
                    ),
                    title: Text(
                      strings.tr(
                        'สำรองและกู้คืนข้อมูล (ในเครื่อง)',
                        'Local Backup & Restore',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      strings.tr(
                        'JSON / ZIP · เข้ารหัสรหัสผ่าน · ย้ายรูปสลิปแยกต่างหาก',
                        'JSON / ZIP · Password encryption · Separate slip image ZIP',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/backup'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Security & Privacy
            _SectionHeader(title: strings.securitySection),
            PremiumCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: <Widget>[
                  SwitchListTile.adaptive(
                    secondary: const Icon(
                      Icons.visibility_off_outlined,
                      color: AppColors.primaryEmerald,
                    ),
                    title: Text(
                      strings.privacyModeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: settings.privacyMode,
                    onChanged: (bool val) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setPrivacyMode(val);
                    },
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.pin_outlined,
                      color: AppColors.primaryEmerald,
                    ),
                    title: Text(
                      strings.pinLockLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      lockState.hasPin
                          ? strings.tr('เปิดใช้งานแล้ว (6 หลัก)', 'Enabled (6 digits)')
                          : strings.tr('ยังไม่ได้ตั้งค่า', 'Not configured'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (lockState.hasPin)
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(appLockControllerProvider.notifier)
                                  .removePin();
                            },
                            child: Text(
                              strings.delete,
                              style: const TextStyle(color: AppColors.expense),
                            ),
                          ),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<bool>(
                                builder: (_) => const PinSetupScreen(),
                              ),
                            );
                          },
                          child: Text(
                            lockState.hasPin
                                ? strings.edit
                                : strings.setupPinTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lockState.hasPin && lockState.biometricSupported) ...<Widget>[
                    const Divider(indent: 56),
                    SwitchListTile.adaptive(
                      secondary: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.primaryEmerald,
                      ),
                      title: Text(
                        strings.biometricUnlockLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: lockState.biometricEnabled,
                      onChanged: (bool val) {
                        ref
                            .read(appLockControllerProvider.notifier)
                            .setBiometricEnabled(
                              val,
                              localizedReason: strings.biometricPromptReason,
                            );
                      },
                    ),
                  ],
                  if (lockState.hasPin) ...<Widget>[
                    const Divider(indent: 56),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.timer_outlined,
                                color: AppColors.primaryEmerald,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  strings.autoLockLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<int>(
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<int>>[
                              ButtonSegment<int>(value: 15, label: Text('15s')),
                              ButtonSegment<int>(value: 60, label: Text('60s')),
                              ButtonSegment<int>(value: 300, label: Text('5m')),
                            ],
                            selected: <int>{
                              <int>{15, 60, 300}.contains(
                                    lockState.autoLockSeconds,
                                  )
                                  ? lockState.autoLockSeconds
                                  : 60,
                            },
                            onSelectionChanged: (Set<int> s) {
                              ref
                                  .read(appLockControllerProvider.notifier)
                                  .setAutoLockSeconds(s.first);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.key_rounded,
                      color: AppColors.primaryEmerald,
                    ),
                    title: Text(
                      strings.changePasswordLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showChangePasswordDialog(
                      context,
                      ref,
                      strings,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Display & Preferences
            _SectionHeader(title: strings.preferencesSection),
            PremiumCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    strings.languageLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<AppLanguage>(
                    segments: const <ButtonSegment<AppLanguage>>[
                      ButtonSegment<AppLanguage>(
                        value: AppLanguage.th,
                        label: Text('ภาษาไทย (TH)'),
                      ),
                      ButtonSegment<AppLanguage>(
                        value: AppLanguage.en,
                        label: Text('English (EN)'),
                      ),
                    ],
                    selected: <AppLanguage>{settings.language},
                    onSelectionChanged: (Set<AppLanguage> next) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setLanguage(next.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      strings.buddhistEraLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: settings.useBuddhistEra,
                    onChanged: (bool val) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setUseBuddhistEra(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.themeModeLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text(strings.themeSystem),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text(strings.themeLight),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text(strings.themeDark),
                      ),
                    ],
                    selected: <ThemeMode>{settings.themeMode},
                    onSelectionChanged: (Set<ThemeMode> next) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setThemeMode(next.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App Version & Auto-Update
            _SectionHeader(
              title: strings.tr('อัปเดตแอปพลิเคชัน', 'App Updates'),
            ),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primaryEmerald,
                ),
                title: Text(
                  strings.tr('ตรวจสอบอัปเดตแอป', 'Check for Updates'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  strings.tr(
                    'เวอร์ชันปัจจุบัน v${AppConfig.appVersion} (Build ${AppConfig.appBuildNumber})',
                    'Current v${AppConfig.appVersion} (Build ${AppConfig.appBuildNumber})',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _checkForUpdatesManually(context, ref, strings),
              ),
            ),
            const SizedBox(height: 24),

            // Logout
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref, strings),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.expense,
                side: const BorderSide(color: AppColors.expense),
                minimumSize: const Size(double.infinity, 52),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                strings.logoutButton,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
