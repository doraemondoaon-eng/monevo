import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../settings/presentation/settings_controller.dart';
import 'auth_controller.dart';

class ServerWakeupScreen extends ConsumerStatefulWidget {
  const ServerWakeupScreen({super.key});

  @override
  ConsumerState<ServerWakeupScreen> createState() => _ServerWakeupScreenState();
}

class _ServerWakeupScreenState extends ConsumerState<ServerWakeupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final double progress =
        (authState.wakeupElapsedSeconds / 60.0).clamp(0.05, 0.95);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 460,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        final AppLanguage current =
                            ref.read(settingsControllerProvider).language;
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setLanguage(
                              current == AppLanguage.th
                                  ? AppLanguage.en
                                  : AppLanguage.th,
                            );
                      },
                      icon: const Icon(Icons.language_rounded, size: 18),
                      label: Text(
                        strings.isThai ? 'EN' : 'ไทย',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (BuildContext context, Widget? child) {
                      final double scale = 1.0 + (_pulseController.value * 0.08);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: <Color>[
                                AppColors.heroStart,
                                AppColors.primaryEmerald,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primaryEmerald.withAlpha(80),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.cloud_sync_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    strings.appName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.serverWakingTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.serverWakingSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  PremiumCard(
                    child: Column(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor:
                                AppColors.primaryEmerald.withAlpha(30),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryEmerald,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              strings.retryAttempt(authState.wakeupAttempt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              strings.elapsedSeconds(
                                authState.wakeupElapsedSeconds,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primaryEmerald,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withAlpha(80),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            AppConfig.deriveHealthUrl(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(authControllerProvider.notifier)
                                .bootstrap();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(strings.retry),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
