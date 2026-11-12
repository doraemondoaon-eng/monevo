import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      _errorMessage = null;
      if (!_isConfirmStep) {
        if (_firstPin.length < 6) {
          _firstPin += digit;
        }
        if (_firstPin.length == 6) {
          _isConfirmStep = true;
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += digit;
        }
        if (_confirmPin.length == 6) {
          _verifyAndSave();
        }
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    setState(() {
      _errorMessage = null;
      if (!_isConfirmStep) {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirmStep = false;
          _firstPin = '';
        }
      }
    });
  }

  Future<void> _verifyAndSave() async {
    final AppStrings strings = AppStrings.of(context);
    if (_firstPin != _confirmPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = strings.pinMismatchError;
        _firstPin = '';
        _confirmPin = '';
        _isConfirmStep = false;
      });
      return;
    }

    await ref.read(appLockControllerProvider.notifier).setPin(_firstPin);
    HapticFeedback.mediumImpact();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final String activePin = _isConfirmStep ? _confirmPin : _firstPin;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isConfirmStep ? strings.confirmPinTitle : strings.setupPinTitle,
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 420,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const SizedBox(height: 12),
              Column(
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(24),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pin_rounded,
                      color: AppColors.primaryEmerald,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isConfirmStep
                        ? strings.confirmPinTitle
                        : strings.setupPinTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.enterPinPrompt,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  PinDotsIndicator(filledCount: activePin.length),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              PinNumericKeypad(
                onDigit: _onDigitPressed,
                onBackspace: _onBackspace,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinDotsIndicator extends StatelessWidget {
  const PinDotsIndicator({
    super.key,
    required this.filledCount,
    this.hasError = false,
  });

  final int filledCount;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final Color activeColor =
        hasError ? AppColors.expense : AppColors.primaryEmerald;
    final Color inactiveColor =
        Theme.of(context).colorScheme.outlineVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(6, (int index) {
        final bool isFilled = index < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: isFilled ? 16 : 14,
          height: isFilled ? 16 : 14,
          decoration: BoxDecoration(
            color: isFilled ? activeColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isFilled ? activeColor : inactiveColor,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class PinNumericKeypad extends StatelessWidget {
  const PinNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.bottomLeftAction,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? bottomLeftAction;

  @override
  Widget build(BuildContext context) {
    final List<List<String>> rows = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final List<String> row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map(
                      (String d) => _KeypadDigitButton(
                        digit: d,
                        onTap: () => onDigit(d),
                      ),
                    )
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Center(child: bottomLeftAction),
                ),
                _KeypadDigitButton(
                  digit: '0',
                  onTap: () => onDigit('0'),
                ),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: IconButton(
                    onPressed: onBackspace,
                    icon: const Icon(Icons.backspace_outlined, size: 26),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeypadDigitButton extends StatelessWidget {
  const _KeypadDigitButton({
    required this.digit,
    required this.onTap,
  });

  final String digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              digit,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
