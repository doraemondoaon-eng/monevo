import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _entranceController.value = 1.0;
      _ambientController.stop();
    } else {
      if (!_entranceStarted) {
        _entranceStarted = true;
        _entranceController.forward();
      }
      if (!_ambientController.isAnimating) {
        _ambientController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final AppStrings strings = AppStrings.of(context);
    final bool showWakeupCard =
        authState.wakeupAttempt > 1 ||
        authState.wakeupElapsedSeconds >= 3 ||
        authState.error != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF03211B),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _SplashBackdrop(ambientAnimation: _ambientController),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: ResponsiveCenter(
                        maxWidth: 460,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _LanguageBar(strings: strings),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _MonevoIconMedallion(
                                    entranceAnimation: _entranceController,
                                    ambientAnimation: _ambientController,
                                  ),
                                  const SizedBox(height: 30),
                                  _AnimatedBrandWordmark(
                                    entranceAnimation: _entranceController,
                                    ambientAnimation: _ambientController,
                                    strings: strings,
                                  ),
                                ],
                              ),
                            ),
                            _SplashFooter(
                              entranceAnimation: _entranceController,
                              ambientAnimation: _ambientController,
                              authState: authState,
                              showWakeupCard: showWakeupCard,
                              strings: strings,
                              onRetry: () {
                                ref
                                    .read(authControllerProvider.notifier)
                                    .bootstrap();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageBar extends ConsumerWidget {
  const _LanguageBar({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () {
          final AppLanguage current =
              ref.read(settingsControllerProvider).language;
          ref
              .read(settingsControllerProvider.notifier)
              .setLanguage(
                current == AppLanguage.th ? AppLanguage.en : AppLanguage.th,
              );
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withAlpha(225),
          backgroundColor: Colors.white.withAlpha(18),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withAlpha(32)),
          ),
        ),
        icon: const Icon(Icons.language_rounded, size: 16),
        label: Text(
          strings.isThai ? 'EN' : 'ไทย',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop({required this.ambientAnimation});

  final Animation<double> ambientAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambientAnimation,
      builder: (BuildContext context, Widget? child) {
        final double wave = math.sin(ambientAnimation.value * 2 * math.pi);
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF021D17),
                AppColors.heroStart,
                AppColors.heroMiddle,
                Color(0xFF03231C),
              ],
              stops: <double>[0.0, 0.35, 0.72, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _BackdropPainter(wave: wave),
            child: child,
          ),
        );
      },
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.wave});

  final double wave;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.42);
    final double maxRadius = math.max(size.width, size.height) * 0.65;

    final Paint topGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.primaryEmeraldLight.withAlpha(56 + (wave * 10).round()),
          AppColors.primaryEmerald.withAlpha(18),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(center.dx, center.dy - wave * 8),
          radius: maxRadius * 0.68,
        ),
      );
    canvas.drawCircle(center, maxRadius * 0.68, topGlow);

    final Paint goldAccentGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.accentGoldLight.withAlpha(22),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.84, size.height * 0.18 + wave * 12),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.18 + wave * 12),
      size.width * 0.45,
      goldAccentGlow,
    );

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withAlpha(14);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, 110.0 * i + wave * 4, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.wave != wave;
}

class _MonevoIconMedallion extends StatelessWidget {
  const _MonevoIconMedallion({
    required this.entranceAnimation,
    required this.ambientAnimation,
  });

  final Animation<double> entranceAnimation;
  final Animation<double> ambientAnimation;

  @override
  Widget build(BuildContext context) {
    final Animation<double> opacity = CurvedAnimation(
      parent: entranceAnimation,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );
    final Animation<double> scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: entranceAnimation,
        curve: const Interval(0.05, 0.68, curve: Curves.easeOutBack),
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        entranceAnimation,
        ambientAnimation,
      ]),
      builder: (BuildContext context, Widget? child) {
        final double t = ambientAnimation.value;
        final double floatOffset = math.sin(t * 2 * math.pi) * 3.5;
        final double sheenOffset = (t * 2.4) - 0.7;

        return Opacity(
          opacity: opacity.value,
          child: Transform.translate(
            offset: Offset(0, floatOffset),
            child: Transform.scale(
              scale: scale.value,
              child: SizedBox(
                width: 184,
                height: 184,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    _PulseRing(phase: t, maxRadius: 176),
                    _PulseRing(phase: (t + 0.5) % 1.0, maxRadius: 176),
                    Container(
                      width: 118,
                      height: 118,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.incomeDark.withAlpha(220),
                            Colors.white.withAlpha(180),
                            AppColors.accentGoldLight.withAlpha(180),
                            AppColors.primaryEmerald,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.incomeDark.withAlpha(65),
                            blurRadius: 34,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withAlpha(90),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(29.5),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.asset(
                              'assets/icon/app_icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _FallbackBrandGlyph(),
                            ),
                            if (sheenOffset > -0.6 && sheenOffset < 1.6)
                              IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        sheenOffset - 0.45,
                                        -1.0,
                                      ),
                                      end: Alignment(
                                        sheenOffset + 0.45,
                                        1.0,
                                      ),
                                      colors: <Color>[
                                        Colors.transparent,
                                        Colors.white.withAlpha(48),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.phase,
    required this.maxRadius,
  });

  final double phase;
  final double maxRadius;

  @override
  Widget build(BuildContext context) {
    final double size = 114 + (maxRadius - 114) * phase;
    final int alpha = ((1.0 - phase) * 52).round().clamp(0, 255);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30 + 18 * phase),
        border: Border.all(
          color: AppColors.incomeDark.withAlpha(alpha),
          width: 1.4,
        ),
      ),
    );
  }
}

class _FallbackBrandGlyph extends StatelessWidget {
  const _FallbackBrandGlyph();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.heroEnd, AppColors.primaryEmerald],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.account_balance_wallet_rounded,
          color: Colors.white,
          size: 52,
        ),
      ),
    );
  }
}

class _AnimatedBrandWordmark extends StatelessWidget {
  const _AnimatedBrandWordmark({
    required this.entranceAnimation,
    required this.ambientAnimation,
    required this.strings,
  });

  final Animation<double> entranceAnimation;
  final Animation<double> ambientAnimation;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Animation<double> titleProgress = CurvedAnimation(
      parent: entranceAnimation,
      curve: const Interval(0.22, 0.78, curve: Curves.easeOutCubic),
    );
    final Animation<double> mottoProgress = CurvedAnimation(
      parent: entranceAnimation,
      curve: const Interval(0.40, 0.92, curve: Curves.easeOutCubic),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            titleProgress,
            ambientAnimation,
          ]),
          builder: (BuildContext context, Widget? child) {
            final double p = titleProgress.value;
            final double spacing = 5.4 - (3.0 * p);
            final double sweep = (ambientAnimation.value * 2.2) - 0.6;

            return Opacity(
              opacity: p,
              child: Transform.translate(
                offset: Offset(0, (1.0 - p) * 18),
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment(sweep - 0.4, -0.3),
                      end: Alignment(sweep + 0.4, 0.3),
                      colors: <Color>[
                        Colors.transparent,
                        Colors.white.withAlpha(85),
                        Colors.transparent,
                      ],
                    ).createShader(bounds);
                  },
                  child: Text.rich(
                    TextSpan(
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: spacing,
                        height: 1.05,
                        color: AppColors.darkTextPrimary,
                      ),
                      children: const <InlineSpan>[
                        TextSpan(text: 'MONE'),
                        TextSpan(
                          text: 'V',
                          style: TextStyle(color: AppColors.incomeDark),
                        ),
                        TextSpan(text: 'O'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: mottoProgress,
          builder: (BuildContext context, Widget? child) {
            final double p = mottoProgress.value;
            return Opacity(
              opacity: p,
              child: Transform.translate(
                offset: Offset(0, (1.0 - p) * 12),
                child: child,
              ),
            );
          },
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _GradientHairline(reverse: true),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          strings.brandMotto.toUpperCase(),
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFA7F3D0),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _GradientHairline(reverse: false),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                strings.appTagline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(190),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientHairline extends StatelessWidget {
  const _GradientHairline({required this.reverse});

  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 1.2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: reverse
              ? <Color>[
                  Colors.transparent,
                  AppColors.incomeDark.withAlpha(180),
                ]
              : <Color>[
                  AppColors.incomeDark.withAlpha(180),
                  Colors.transparent,
                ],
        ),
      ),
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter({
    required this.entranceAnimation,
    required this.ambientAnimation,
    required this.authState,
    required this.showWakeupCard,
    required this.strings,
    required this.onRetry,
  });

  final Animation<double> entranceAnimation;
  final Animation<double> ambientAnimation;
  final AuthState authState;
  final bool showWakeupCard;
  final AppStrings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Animation<double> footerFade = CurvedAnimation(
      parent: entranceAnimation,
      curve: const Interval(0.48, 1.0, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: footerFade,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: showWakeupCard
              ? _ColdStartStatusCard(
                  key: const ValueKey<String>('wakeup-card'),
                  authState: authState,
                  strings: strings,
                  onRetry: onRetry,
                )
              : _MinimalSplashLoader(
                  key: const ValueKey<String>('minimal-loader'),
                  ambientAnimation: ambientAnimation,
                  strings: strings,
                ),
        ),
      ),
    );
  }
}

class _MinimalSplashLoader extends StatelessWidget {
  const _MinimalSplashLoader({
    super.key,
    required this.ambientAnimation,
    required this.strings,
  });

  final Animation<double> ambientAnimation;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 196,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: Colors.white.withAlpha(32)),
                AnimatedBuilder(
                  animation: ambientAnimation,
                  builder: (BuildContext context, Widget? child) {
                    final double alignX = -1.6 + (ambientAnimation.value * 3.2);
                    return Align(
                      alignment: Alignment(alignX, 0),
                      child: Container(
                        width: 84,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              AppColors.incomeDark,
                              Color(0xFFA7F3D0),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          strings.splashPreparing,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withAlpha(195),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: AppColors.incomeDark.withAlpha(220),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  strings.splashSecurityBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColdStartStatusCard extends StatelessWidget {
  const _ColdStartStatusCard({
    super.key,
    required this.authState,
    required this.strings,
    required this.onRetry,
  });

  final AuthState authState;
  final AppStrings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress =
        (authState.wakeupElapsedSeconds / 60.0).clamp(0.06, 0.95);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(36)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.incomeDark,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  strings.serverWakingTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.serverWakingSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withAlpha(185),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withAlpha(26),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.incomeDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  strings.retryAttempt(authState.wakeupAttempt),
                  style: AppTheme.tabularStyle(
                    (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: Colors.white.withAlpha(190),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  strings.elapsedSeconds(authState.wakeupElapsedSeconds),
                  style: AppTheme.tabularStyle(
                    (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: AppColors.incomeDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withAlpha(65)),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(strings.retry),
          ),
        ],
      ),
    );
  }
}
