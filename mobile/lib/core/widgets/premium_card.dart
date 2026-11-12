import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'monevo_feedback.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.gradient,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveBg = backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final Color effectiveBorder = borderColor ??
        (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    final BorderRadius radius = BorderRadius.circular(borderRadius);

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = BouncyTap(
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: null,
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? effectiveBg : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: gradient == null
              ? effectiveBorder
              : Colors.white.withAlpha(24),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 18 : 6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }
}
