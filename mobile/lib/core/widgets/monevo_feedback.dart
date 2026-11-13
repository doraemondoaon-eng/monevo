import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

// =============================================================================
// 1. BOUNCY TAP (Spring Button / Card Micro-Interaction)
// =============================================================================

/// A tactile wrapper that applies a smooth spring scale animation and haptic
/// feedback when pressed, providing an ultra-responsive native feel.
class BouncyTap extends StatefulWidget {
  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
    this.duration = const Duration(milliseconds: 110),
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration duration;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptic) {
                HapticFeedback.mediumImpact();
              }
              widget.onLongPress!();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// 2. MONEVO ALERT & TOAST SYSTEM (SweetAlert2 Style)
// =============================================================================

enum MonevoAlertType { success, error, warning, info }

class MonevoAlert {
  MonevoAlert._();

  /// Displays an animated SweetAlert2-style modal with a bouncy checkmark,
  /// amount preview, category/account badges, and optional auto-dismiss.
  static Future<void> showSuccess(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? amountFormatted,
    Color? amountColor,
    String? categoryName,
    String? accountName,
    IconData? customIcon,
    Color? customColor,
    String confirmLabel = 'ตกลง',
    Duration autoDismissDuration = const Duration(milliseconds: 2300),
    VoidCallback? onDismissed,
  }) async {
    HapticFeedback.mediumImpact();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MonevoAlertDismiss',
      barrierColor: Colors.black.withAlpha(120),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) {
        return _SweetAlertModal(
          title: title,
          subtitle: subtitle,
          amountFormatted: amountFormatted,
          amountColor: amountColor ?? (customColor ?? AppColors.primaryEmerald),
          categoryName: categoryName,
          accountName: accountName,
          customIcon: customIcon,
          customColor: customColor,
          confirmLabel: confirmLabel,
          type: MonevoAlertType.success,
          autoDismissDuration: autoDismissDuration,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final CurvedAnimation springCurve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 4 * anim.value,
            sigmaY: 4 * anim.value,
          ),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.75, end: 1.0).animate(springCurve),
              child: child,
            ),
          ),
        );
      },
    );

    onDismissed?.call();
  }

  /// Displays an animated confirmation popup (SweetAlert Confirm) with warning badge
  /// and high-contrast destructive button.
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'ยืนยัน',
    String cancelLabel = 'ยกเลิก',
    bool isDestructive = false,
    IconData icon = Icons.warning_amber_rounded,
  }) async {
    HapticFeedback.lightImpact();

    final bool? result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MonevoAlertConfirmDismiss',
      barrierColor: Colors.black.withAlpha(120),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return _SweetConfirmModal(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          isDestructive: isDestructive,
          icon: icon,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final CurvedAnimation spring = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 4 * anim.value,
            sigmaY: 4 * anim.value,
          ),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1.0).animate(spring),
              child: child,
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  /// Displays an animated error alert with shake effect and red pulse.
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'ตกลง',
  }) async {
    HapticFeedback.heavyImpact();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MonevoAlertErrorDismiss',
      barrierColor: Colors.black.withAlpha(120),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return _SweetAlertModal(
          title: title,
          subtitle: message,
          confirmLabel: confirmLabel,
          type: MonevoAlertType.error,
          autoDismissDuration: null,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 4 * anim.value,
            sigmaY: 4 * anim.value,
          ),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Non-blocking floating pill toast that drops smoothly from the top
  /// (Dynamic Island style) with spring physics and auto-dismisses.
  static void showToast(
    BuildContext context, {
    required String message,
    IconData? icon,
    MonevoAlertType type = MonevoAlertType.success,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    HapticFeedback.selectionClick();

    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) {
        return _FloatingToast(
          message: message,
          icon: icon,
          type: type,
          duration: duration,
          onRemove: () {
            try {
              entry.remove();
            } catch (_) {}
          },
        );
      },
    );

    overlay.insert(entry);
  }
}

// =============================================================================
// 3. SWEET ALERT MODAL IMPLEMENTATION
// =============================================================================

class _SweetAlertModal extends StatefulWidget {
  const _SweetAlertModal({
    required this.title,
    this.subtitle,
    this.amountFormatted,
    this.amountColor,
    this.categoryName,
    this.accountName,
    this.customIcon,
    this.customColor,
    required this.confirmLabel,
    required this.type,
    this.autoDismissDuration,
  });

  final String title;
  final String? subtitle;
  final String? amountFormatted;
  final Color? amountColor;
  final String? categoryName;
  final String? accountName;
  final IconData? customIcon;
  final Color? customColor;
  final String confirmLabel;
  final MonevoAlertType type;
  final Duration? autoDismissDuration;

  @override
  State<_SweetAlertModal> createState() => _SweetAlertModalState();
}

class _SweetAlertModalState extends State<_SweetAlertModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    if (widget.autoDismissDuration != null) {
      _dismissTimer = Timer(widget.autoDismissDuration!, () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color _resolveColor(bool isDark) {
    if (widget.customColor != null) {
      return widget.customColor!;
    }
    switch (widget.type) {
      case MonevoAlertType.success:
        return AppColors.primaryEmerald;
      case MonevoAlertType.error:
        return AppColors.expense;
      case MonevoAlertType.warning:
        return AppColors.warning;
      case MonevoAlertType.info:
        return isDark ? AppColors.primaryEmeraldLight : AppColors.primaryEmerald;
    }
  }

  IconData _resolveIcon() {
    if (widget.customIcon != null) {
      return widget.customIcon!;
    }
    switch (widget.type) {
      case MonevoAlertType.success:
        return Icons.check_rounded;
      case MonevoAlertType.error:
        return Icons.close_rounded;
      case MonevoAlertType.warning:
        return Icons.priority_high_rounded;
      case MonevoAlertType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = _resolveColor(isDark);
    final Color bg = isDark ? const Color(0xFF1E2630) : Colors.white;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 330,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 35),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: accent.withAlpha(isDark ? 30 : 25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(24) : Colors.black.withAlpha(12),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Animated Pulse Icon Circle
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (BuildContext ctx, Widget? child) {
                  final double glow = 8 + (_pulseCtrl.value * 6);
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withAlpha(isDark ? 90 : 70),
                          blurRadius: glow,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _resolveIcon(),
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
              ),

              // Amount Badge (if present)
              if (widget.amountFormatted != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (widget.amountColor ?? accent).withAlpha(isDark ? 36 : 22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (widget.amountColor ?? accent).withAlpha(80),
                    ),
                  ),
                  child: Text(
                    widget.amountFormatted!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: widget.amountColor ?? accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],

              // Info chips (Category / Account)
              if (widget.categoryName != null || widget.accountName != null) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    if (widget.categoryName != null)
                      _InfoChip(
                        icon: Icons.category_outlined,
                        label: widget.categoryName!,
                        isDark: isDark,
                      ),
                    if (widget.accountName != null)
                      _InfoChip(
                        icon: Icons.account_balance_wallet_outlined,
                        label: widget.accountName!,
                        isDark: isDark,
                      ),
                  ],
                ),
              ],

              // Subtitle
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],

              const SizedBox(height: 22),

              // Action button with BouncyTap
              SizedBox(
                width: double.infinity,
                height: 46,
                child: BouncyTap(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withAlpha(70),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.confirmLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 4. SWEET CONFIRM MODAL
// =============================================================================

class _SweetConfirmModal extends StatelessWidget {
  const _SweetConfirmModal({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color badgeColor = isDestructive ? AppColors.expense : AppColors.warning;
    final Color bg = isDark ? const Color(0xFF1E2630) : Colors.white;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 330,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 35),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(24) : Colors.black.withAlpha(12),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Warning / Danger badge
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor.withAlpha(28),
                  border: Border.all(color: badgeColor.withAlpha(80), width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: badgeColor,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 22),

              // Action buttons row with BouncyTap
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: BouncyTap(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(false);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(16)
                                : Colors.black.withAlpha(8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cancelLabel,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: BouncyTap(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop(true);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: badgeColor.withAlpha(70),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. FLOATING DYNAMIC ISLAND TOAST
// =============================================================================

class _FloatingToast extends StatefulWidget {
  const _FloatingToast({
    required this.message,
    this.icon,
    required this.type,
    required this.duration,
    required this.onRemove,
  });

  final String message;
  final IconData? icon;
  final MonevoAlertType type;
  final Duration duration;
  final VoidCallback onRemove;

  @override
  State<_FloatingToast> createState() => _FloatingToastState();
}

class _FloatingToastState extends State<_FloatingToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    _timer = Timer(widget.duration, () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onRemove();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color _resolveColor() {
    switch (widget.type) {
      case MonevoAlertType.success:
        return AppColors.primaryEmerald;
      case MonevoAlertType.error:
        return AppColors.expense;
      case MonevoAlertType.warning:
        return AppColors.warning;
      case MonevoAlertType.info:
        return AppColors.primaryEmeraldLight;
    }
  }

  IconData _resolveIcon() {
    if (widget.icon != null) return widget.icon!;
    switch (widget.type) {
      case MonevoAlertType.success:
        return Icons.check_circle_rounded;
      case MonevoAlertType.error:
        return Icons.error_rounded;
      case MonevoAlertType.warning:
        return Icons.warning_amber_rounded;
      case MonevoAlertType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.paddingOf(context).top + 12;
    final Color accent = _resolveColor();

    return Positioned(
      top: topPadding,
      left: 20,
      right: 20,
      child: Center(
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A22).withAlpha(240),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withAlpha(30),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withAlpha(70),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: accent.withAlpha(30),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _resolveIcon(),
                      color: accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
