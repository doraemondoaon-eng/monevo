import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/dashboard_models.dart';

/// Soft pastel mint ambient corner glow behind the dashboard content.
class DashboardAmbientBackground extends StatelessWidget {
  const DashboardAmbientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
              ),
              child: Stack(
                children: <Widget>[
                  // Upper-right diagonal mint wave / glow
                  Positioned(
                    top: -60,
                    right: -80,
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            AppColors.income.withAlpha(isDark ? 26 : 36),
                            AppColors.primaryEmeraldLight
                                .withAlpha(isDark ? 12 : 16),
                            Colors.transparent,
                          ],
                          stops: const <double>[0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Mid-left soft emerald wash
                  Positioned(
                    top: 240,
                    left: -110,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            AppColors.primaryEmerald
                                .withAlpha(isDark ? 18 : 22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Lower-right ambient tint
                  Positioned(
                    bottom: 60,
                    right: -60,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            AppColors.income.withAlpha(isDark ? 18 : 28),
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
        ),
        child,
      ],
    );
  }
}

/// Crisp two-tone folded emerald ribbon "M" brand mark matching MONEVO identity.
class MonevoBrandMark extends StatelessWidget {
  const MonevoBrandMark({super.key, this.width = 36, this.height = 26});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: const _MonevoLogoPainter(),
    );
  }
}

class _MonevoLogoPainter extends CustomPainter {
  const _MonevoLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = h * 0.25;

    final Paint leftLegPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF047857), Color(0xFF10B981)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint leftMidPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF34D399), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint rightMidPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF059669), Color(0xFF34D399)],
        begin: Alignment.bottomCenter,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint rightLegPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topRight,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Offset p0 = Offset(stroke * 0.55, h - stroke * 0.55);
    final Offset p1 = Offset(w * 0.23, stroke * 0.6);
    final Offset p2 = Offset(w * 0.50, h - stroke * 0.65);
    final Offset p3 = Offset(w * 0.77, stroke * 0.6);
    final Offset p4 = Offset(w - stroke * 0.55, h - stroke * 0.55);

    canvas.drawLine(p0, p1, leftLegPaint);
    canvas.drawLine(p1, p2, leftMidPaint);
    canvas.drawLine(p2, p3, rightMidPaint);
    canvas.drawLine(p3, p4, rightLegPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mini emerald bars + upward arrow icon for Net Worth card title.
class HeroNetWorthHeaderIcon extends StatelessWidget {
  const HeroNetWorthHeaderIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _HeroNetWorthHeaderIconPainter(),
    );
  }
}

class _HeroNetWorthHeaderIconPainter extends CustomPainter {
  const _HeroNetWorthHeaderIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint barPaint = Paint()
      ..color = const Color(0xFF34D399)
      ..style = PaintingStyle.fill;

    // 3 small ascending bars
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.60, w * 0.20, h * 0.32),
        const Radius.circular(2),
      ),
      barPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.44, w * 0.20, h * 0.48),
        const Radius.circular(2),
      ),
      barPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.68, h * 0.28, w * 0.20, h * 0.64),
        const Radius.circular(2),
      ),
      barPaint,
    );

    // Rising arrow line over the bars
    final Paint arrowPaint = Paint()
      ..color = const Color(0xFF6EE7B7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path()
      ..moveTo(w * 0.08, h * 0.44)
      ..lineTo(w * 0.42, h * 0.28)
      ..lineTo(w * 0.88, h * 0.08);
    canvas.drawPath(path, arrowPaint);

    // Arrowhead
    final Path head = Path()
      ..moveTo(w * 0.64, h * 0.06)
      ..lineTo(w * 0.90, h * 0.08)
      ..lineTo(w * 0.86, h * 0.30);
    canvas.drawPath(head, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Luminous green ascending curve with glowing endpoint rendered inside the Hero card.
class HeroGrowthSparkline extends StatelessWidget {
  const HeroGrowthSparkline({super.key, required this.points});

  final List<NetWorthPoint> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HeroGrowthSparklinePainter(points: points),
    );
  }
}

class _HeroGrowthSparklinePainter extends CustomPainter {
  const _HeroGrowthSparklinePainter({required this.points});

  final List<NetWorthPoint> points;

  List<double> _normalizedYSeries() {
    if (points.length >= 2) {
      double minV = points.first.netWorth.toDouble();
      double maxV = points.first.netWorth.toDouble();
      for (final NetWorthPoint p in points) {
        final double v = p.netWorth.toDouble();
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      final double span = maxV - minV;
      if (span > 0) {
        // Sample up to 6 key points cleanly for smooth curve aesthetic
        final int targetCount = math.min(6, points.length);
        final List<double> sampled = <double>[];
        for (int i = 0; i < targetCount; i++) {
          final int idx = ((i * (points.length - 1)) / (targetCount - 1))
              .round()
              .clamp(0, points.length - 1);
          final double norm =
              (points[idx].netWorth.toDouble() - minV) / span;
          sampled.add(0.15 + norm * 0.72);
        }
        return sampled;
      }
    }
    // Graceful rising fintech baseline when balance hasn't fluctuated yet
    return const <double>[0.12, 0.24, 0.32, 0.56, 0.52, 0.84];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final List<double> ys = _normalizedYSeries();
    final List<Offset> pts = <Offset>[];
    final double rightPad = 14.0;
    final double leftStart = 6.0;
    final double usableW = math.max(10.0, w - leftStart - rightPad);

    for (int i = 0; i < ys.length; i++) {
      final double x = leftStart + (usableW * i / (ys.length - 1));
      final double y = h - (ys[i] * (h - 14)) - 6;
      pts.add(Offset(x, y));
    }

    final Path linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final Offset p0 = pts[i];
      final Offset p1 = pts[i + 1];
      final double midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Soft glowing area underneath curve
    final Path fillPath = Path.from(linePath)
      ..lineTo(pts.last.dx, h)
      ..lineTo(pts.first.dx, h)
      ..close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          const Color(0xFF22C55E).withAlpha(65),
          const Color(0xFF10B981).withAlpha(18),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Outer neon green aura
    final Paint glowPaint = Paint()
      ..color = const Color(0xFF4ADE80).withAlpha(75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);

    // Sharp bright green trend line
    final Paint linePaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          const Color(0xFF10B981).withAlpha(60),
          const Color(0xFF4ADE80),
          const Color(0xFF86EFAC),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Intermediate nodes
    final Paint nodePaint = Paint()..color = const Color(0xFF86EFAC);
    for (int i = 1; i < pts.length - 1; i++) {
      canvas.drawCircle(pts[i], 2.7, nodePaint);
    }

    // Radiant peak endpoint
    final Offset last = pts.last;
    canvas.drawCircle(
      last,
      9,
      Paint()
        ..color = const Color(0xFF4ADE80).withAlpha(110)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(last, 4.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _HeroGrowthSparklinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

/// Cute stacked golden coins icon for Total Income inside Hero card.
class GoldCoinsIcon extends StatelessWidget {
  const GoldCoinsIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoldCoinsPainter(),
    );
  }
}

class _GoldCoinsPainter extends CustomPainter {
  const _GoldCoinsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint rimPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.fill;
    final Paint facePaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFFDE68A), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Draw 3 stacked horizontal coin discs
    for (int i = 0; i < 3; i++) {
      final double yBase = h * (0.72 - i * 0.21);
      final double xOffset = i == 1 ? w * 0.05 : 0.0;
      final Rect sideRect = Rect.fromCenter(
        center: Offset(w * 0.5 + xOffset, yBase + h * 0.05),
        width: w * 0.72,
        height: h * 0.24,
      );
      canvas.drawOval(sideRect, rimPaint);

      final Rect topRect = Rect.fromCenter(
        center: Offset(w * 0.5 + xOffset, yBase),
        width: w * 0.72,
        height: h * 0.24,
      );
      canvas.drawOval(topRect, facePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cute coral wallet icon for Total Expense inside Hero card.
class CoralWalletIcon extends StatelessWidget {
  const CoralWalletIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _CoralWalletPainter(),
    );
  }
}

class _CoralWalletPainter extends CustomPainter {
  const _CoralWalletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Back flap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.14, w * 0.68, h * 0.22),
        Radius.circular(w * 0.10),
      ),
      Paint()..color = const Color(0xFFE11D48),
    );

    // Wallet body
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFFB7185), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.24, w * 0.80, h * 0.62),
        Radius.circular(w * 0.18),
      ),
      bodyPaint,
    );

    // Clasp strap on right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.44, w * 0.30, h * 0.22),
        Radius.circular(w * 0.09),
      ),
      Paint()..color = const Color(0xFFBE123C),
    );

    // White clasp button dot
    canvas.drawCircle(
      Offset(w * 0.72, h * 0.55),
      w * 0.05,
      Paint()..color = const Color(0xFFFFE4E6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cute golden piggy bank icon for Total Liabilities inside Hero card.
class GoldenPiggyIcon extends StatelessWidget {
  const GoldenPiggyIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoldenPiggyPainter(),
    );
  }
}

class _GoldenPiggyPainter extends CustomPainter {
  const _GoldenPiggyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint goldPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFFDE68A), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.68, w * 0.14, h * 0.18),
        Radius.circular(w * 0.06),
      ),
      goldPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.58, h * 0.68, w * 0.14, h * 0.18),
        Radius.circular(w * 0.06),
      ),
      goldPaint,
    );

    // Ear
    final Path ear = Path()
      ..moveTo(w * 0.30, h * 0.32)
      ..lineTo(w * 0.36, h * 0.16)
      ..lineTo(w * 0.48, h * 0.28)
      ..close();
    canvas.drawPath(ear, goldPaint);

    // Main round body
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.52),
        width: w * 0.72,
        height: h * 0.52,
      ),
      goldPaint,
    );

    // Snout on left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.44, w * 0.16, h * 0.18),
        Radius.circular(w * 0.06),
      ),
      Paint()..color = const Color(0xFFFBBF24),
    );

    // Coin slot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.44, h * 0.32, w * 0.20, h * 0.05),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = const Color(0xFF92400E),
    );

    // Eye
    canvas.drawCircle(
      Offset(w * 0.32, h * 0.46),
      w * 0.04,
      Paint()..color = const Color(0xFF78350F),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Crisp two-tone emerald circular pie icon for Monthly Summary card header.
class EmeraldPieIcon extends StatelessWidget {
  const EmeraldPieIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _EmeraldPiePainter(),
    );
  }
}

class _EmeraldPiePainter extends CustomPainter {
  const _EmeraldPiePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = size.width * 0.46;

    // Darker emerald base circle (270 deg)
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFF047857),
    );

    // Lighter glowing mint upper-right slice
    final Rect oval = Rect.fromCircle(
      center: Offset(center.dx + size.width * 0.03, center.dy - size.height * 0.03),
      radius: r,
    );
    canvas.drawArc(
      oval,
      -math.pi / 2,
      math.pi * 0.65,
      true,
      Paint()..color = const Color(0xFF34D399),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Faint ascending bar chart watermark rendered in the bottom-right corner
/// of the Monthly Summary income/expense cards.
class MiniBarWatermark extends StatelessWidget {
  const MiniBarWatermark({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(64, 52),
      painter: _MiniBarWatermarkPainter(color: color),
    );
  }
}

class _MiniBarWatermarkPainter extends CustomPainter {
  const _MiniBarWatermarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const List<double> heights = <double>[0.36, 0.56, 0.74, 0.96];
    final double barWidth = size.width * 0.17;
    final double gap = size.width * 0.07;

    for (int i = 0; i < heights.length; i++) {
      final double bh = size.height * heights[i];
      final double left = i * (barWidth + gap);
      final double top = size.height - bh;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, top, barWidth, bh),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBarWatermarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

