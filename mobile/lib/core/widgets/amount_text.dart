import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/money_utils.dart';

class AmountText extends ConsumerWidget {
  const AmountText({
    super.key,
    required this.satang,
    this.style,
    this.showPlusSign = false,
    this.alwaysShowDecimals = true,
    this.compact = false,
    this.respectPrivacy = true,
    this.textAlign,
    this.maxLines = 1,
  });

  final int satang;
  final TextStyle? style;
  final bool showPlusSign;
  final bool alwaysShowDecimals;
  final bool compact;
  final bool respectPrivacy;
  final TextAlign? textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isPrivacy = respectPrivacy
        ? ref.watch(
            settingsControllerProvider.select(
              (AppSettingsState s) => s.privacyMode,
            ),
          )
        : false;

    final String formatted = compact
        ? MoneyUtils.formatCompactSatang(satang)
        : MoneyUtils.formatSatang(
            satang,
            showPlusSign: showPlusSign,
            alwaysShowDecimals: alwaysShowDecimals,
          );

    final TextStyle effectiveStyle = AppTheme.tabularStyle(
      style ?? DefaultTextStyle.of(context).style,
    );

    final Widget textWidget = Text(
      isPrivacy ? '฿ ••••••' : formatted,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );

    if (!isPrivacy) {
      return textWidget;
    }

    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
      child: textWidget,
    );
  }
}
