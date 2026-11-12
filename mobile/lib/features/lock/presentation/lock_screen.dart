import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../../auth/presentation/auth_controller.dart';
import 'pin_setup_screen.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoBiometric();
    });
  }

  Future<void> _tryAutoBiometric() async {
    if (!mounted) {
      return;
    }
    final AppLockState lockState = ref.read(appLockControllerProvider);
    if (lockState.biometricEnabled && lockState.biometricSupported) {
      final AppStrings strings = AppStrings.of(context);
      await ref
          .read(appLockControllerProvider.notifier)
          .unlockWithBiometrics(strings.biometricPromptReason);
    }
  }

  Future<void> _onDigit(String digit) async {
    if (_pin.length >= 6) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _hasError = false;
      _pin += digit;
    });

    if (_pin.length == 6) {
      final bool unlocked = await ref
          .read(appLockControllerProvider.notifier)
          .unlockWithPin(_pin);
      if (!mounted) {
        return;
      }
      if (!unlocked) {
        HapticFeedback.heavyImpact();
        setState(() {
          _hasError = true;
          _pin = '';
        });
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _hasError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLockState lockState = ref.watch(appLockControllerProvider);
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 420,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await ref.read(appLockControllerProvider.notifier).removePin();
                    await ref.read(authControllerProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(strings.logoutButton),
                ),
              ),
              Column(
                children: <Widget>[
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          AppColors.heroStart,
                          AppColors.primaryEmerald,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    strings.appLockedTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.enterPinPrompt,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  PinDotsIndicator(
                    filledCount: _pin.length,
                    hasError: _hasError,
                  ),
                  if (_hasError) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      strings.invalidPinError,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              PinNumericKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                bottomLeftAction:
                    (lockState.biometricEnabled && lockState.biometricSupported)
                        ? IconButton(
                            onPressed: _tryAutoBiometric,
                            tooltip: strings.unlockWithBiometrics,
                            icon: const Icon(
                              Icons.fingerprint_rounded,
                              size: 32,
                              color: AppColors.primaryEmerald,
                            ),
                          )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
