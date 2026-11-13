import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import 'icon_mapper.dart';
import 'thai_institution_catalog.dart';

/// Unified account avatar widget.
/// Renders a bespoke Thai financial institution / loan emblem when
/// [institution] (or [accountName] as fallback) matches [ThaiInstitutionCatalog],
/// and smoothly falls back to MONEVO's tinted Material icon badge otherwise.
class AccountBrandAvatar extends StatelessWidget {
  const AccountBrandAvatar({
    super.key,
    required this.institution,
    required this.iconKey,
    required this.colorHex,
    this.accountName,
    this.size = 46,
    this.borderRadius,
  });

  final String? institution;
  final String? accountName;
  final String? iconKey;
  final String? colorHex;
  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThaiInstitution? matched = ThaiInstitutionCatalog.match(
      institution,
      accountName: accountName,
    );
    if (matched != null) {
      return ThaiInstitutionBadge(
        institution: matched,
        overrideColorHex: colorHex,
        size: size,
        borderRadius: borderRadius,
      );
    }

    final Color accColor = AppColors.fromHex(colorHex);
    final double radius = borderRadius ?? (size * 0.30).clamp(6.0, 18.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accColor.withAlpha(30),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        IconMapper.resolve(iconKey),
        color: accColor,
        size: (size * 0.48).clamp(11.0, 28.0),
      ),
    );
  }
}

/// Custom vector-enhanced fintech emblem for Thai banks, e-wallets,
/// credit cards, personal/digital loans, auto/title loans, SLF, and brokers.
class ThaiInstitutionBadge extends StatelessWidget {
  const ThaiInstitutionBadge({
    super.key,
    required this.institution,
    this.overrideColorHex,
    this.size = 46,
    this.borderRadius,
  });

  final ThaiInstitution institution;
  final String? overrideColorHex;
  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color brandPrimary = AppColors.fromHex(institution.primaryHex);
    final Color brandSecondary = AppColors.fromHex(institution.secondaryHex);

    final bool hasCustomOverride =
        overrideColorHex != null &&
        overrideColorHex!.trim().isNotEmpty &&
        overrideColorHex!.trim().toUpperCase() !=
            institution.primaryHex.toUpperCase();

    final Color startColor = hasCustomOverride
        ? AppColors.fromHex(overrideColorHex)
        : brandPrimary;
    final Color endColor = hasCustomOverride
        ? Color.lerp(startColor, Colors.black, 0.28) ?? startColor
        : brandSecondary;
    final Color accentColor = institution.accentHex != null
        ? AppColors.fromHex(institution.accentHex)
        : Colors.white.withAlpha(90);

    final bool useDarkInk = hasCustomOverride
        ? ThemeData.estimateBrightnessForColor(startColor) == Brightness.light
        : institution.darkInk;
    final Color inkColor = useDarkInk
        ? const Color(0xFF1F2937)
        : Colors.white;

    final double radius = borderRadius ?? (size * 0.28).clamp(5.0, 18.0);
    final bool compact = size <= 24;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: compact
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: startColor.withAlpha(64),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[startColor, endColor],
                ),
              ),
            ),
            if (!compact)
              CustomPaint(
                painter: _EmblemMotifPainter(
                  motif: institution.motif,
                  accentColor: accentColor,
                  darkInk: useDarkInk,
                ),
              ),
            // Inner crisp border
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: (useDarkInk ? Colors.black : Colors.white)
                      .withAlpha(compact ? 45 : 55),
                  width: compact ? 0.8 : 1.0,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size * (compact ? 0.10 : 0.12),
                  vertical: size * 0.08,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    institution.shortLabel,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: inkColor,
                      fontSize: (size * 0.34).clamp(8.0, 17.0),
                      fontWeight: FontWeight.w900,
                      letterSpacing:
                          RegExp(r'^[A-Za-z0-9!+\s-]+$')
                                  .hasMatch(institution.shortLabel)
                              ? -0.4
                              : 0.0,
                      height: 1.05,
                      shadows: useDarkInk || compact
                          ? null
                          : const <Shadow>[
                              Shadow(
                                color: Color(0x45000000),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmblemMotifPainter extends CustomPainter {
  const _EmblemMotifPainter({
    required this.motif,
    required this.accentColor,
    required this.darkInk,
  });

  final EmblemMotif motif;
  final Color accentColor;
  final bool darkInk;

  @override
  void paint(Canvas canvas, Size size) {
    final Color baseOverlay =
        (darkInk ? Colors.white : Colors.white).withAlpha(darkInk ? 55 : 28);
    final Paint softPaint = Paint()
      ..color = baseOverlay
      ..style = PaintingStyle.fill;

    final Paint accentPaint = Paint()
      ..color = accentColor.withAlpha(115)
      ..style = PaintingStyle.fill;

    // Subtle top-left glass reflection
    final Path gloss = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.85, 0)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.25,
        0,
        size.height * 0.62,
      )
      ..close();
    canvas.drawPath(
      gloss,
      Paint()..color = Colors.white.withAlpha(darkInk ? 60 : 22),
    );

    switch (motif) {
      case EmblemMotif.leafDiamond:
        canvas.drawCircle(
          Offset(size.width * 0.86, size.height * 0.84),
          size.width * 0.34,
          softPaint,
        );
        final Path cornerAccent = Path()
          ..moveTo(size.width * 0.62, size.height)
          ..lineTo(size.width, size.height * 0.56)
          ..lineTo(size.width, size.height)
          ..close();
        canvas.drawPath(cornerAccent, accentPaint);
      case EmblemMotif.lotusCrest:
        canvas.drawCircle(
          Offset(size.width * 0.82, size.height * 0.16),
          size.width * 0.28,
          softPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.16, size.height * 0.86),
          size.width * 0.22,
          accentPaint..color = accentColor.withAlpha(65),
        );
      case EmblemMotif.diagonalSlash:
        final Path slash = Path()
          ..moveTo(size.width * 0.66, 0)
          ..lineTo(size.width * 0.90, 0)
          ..lineTo(size.width * 0.42, size.height)
          ..lineTo(size.width * 0.18, size.height)
          ..close();
        canvas.drawPath(slash, accentPaint..color = accentColor.withAlpha(80));
      case EmblemMotif.crownArch:
        final Paint arcPaint = Paint()
          ..color = accentColor.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.08;
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.92),
            radius: size.width * 0.68,
          ),
          3.5,
          2.4,
          false,
          arcPaint,
        );
      case EmblemMotif.lightningSpark:
        final Path bolt = Path()
          ..moveTo(size.width * 0.78, size.height * 0.08)
          ..lineTo(size.width * 0.94, size.height * 0.08)
          ..lineTo(size.width * 0.80, size.height * 0.38)
          ..lineTo(size.width * 0.94, size.height * 0.38)
          ..lineTo(size.width * 0.68, size.height * 0.78)
          ..close();
        canvas.drawPath(bolt, accentPaint..color = accentColor.withAlpha(80));
      case EmblemMotif.cardChip:
        // Metallic card EMV chip silhouette in top-left & card stripe at bottom
        final RRect chip = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.12,
            size.height * 0.13,
            size.width * 0.24,
            size.height * 0.16,
          ),
          Radius.circular(size.width * 0.04),
        );
        canvas.drawRRect(chip, softPaint..color = Colors.white.withAlpha(75));
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.84, size.width, size.height * 0.10),
          accentPaint..color = accentColor.withAlpha(95),
        );
      case EmblemMotif.wheelArc:
        final Paint ringPaint = Paint()
          ..color = accentColor.withAlpha(85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.09;
        canvas.drawCircle(
          Offset(size.width * 0.85, size.height * 0.85),
          size.width * 0.34,
          ringPaint,
        );
      case EmblemMotif.walletFold:
        final RRect flap = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.62,
            size.height * 0.64,
            size.width * 0.44,
            size.height * 0.26,
          ),
          Radius.circular(size.width * 0.12),
        );
        canvas.drawRRect(flap, accentPaint..color = accentColor.withAlpha(85));
      case EmblemMotif.shieldCrest:
        final Path shield = Path()
          ..moveTo(size.width * 0.5, size.height * 0.08)
          ..lineTo(size.width * 0.88, size.height * 0.22)
          ..lineTo(size.width * 0.82, size.height * 0.65)
          ..lineTo(size.width * 0.5, size.height * 0.90)
          ..lineTo(size.width * 0.18, size.height * 0.65)
          ..lineTo(size.width * 0.12, size.height * 0.22)
          ..close();
        canvas.drawPath(
          shield,
          Paint()
            ..color = Colors.white.withAlpha(darkInk ? 50 : 24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.055,
        );
      case EmblemMotif.chartTrend:
        final Paint linePaint = Paint()
          ..color = accentColor.withAlpha(110)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.065
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final Path trend = Path()
          ..moveTo(size.width * 0.14, size.height * 0.78)
          ..lineTo(size.width * 0.38, size.height * 0.60)
          ..lineTo(size.width * 0.58, size.height * 0.68)
          ..lineTo(size.width * 0.86, size.height * 0.28);
        canvas.drawPath(trend, linePaint);
    }
  }

  @override
  bool shouldRepaint(_EmblemMotifPainter oldDelegate) {
    return oldDelegate.motif != motif ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.darkInk != darkInk;
  }
}

/// Searchable modal picker for all 76+ Thai banks, e-wallets, credit cards,
/// personal loans, auto/title loans, student loans (กยศ.), and investments.
class ThaiInstitutionPickerSheet extends StatefulWidget {
  const ThaiInstitutionPickerSheet({
    super.key,
    this.selectedInstitution,
    this.initialCategory,
  });

  final ThaiInstitution? selectedInstitution;
  final ThaiInstitutionCategory? initialCategory;

  static Future<ThaiInstitutionPickerResult?> show(
    BuildContext context, {
    ThaiInstitution? selected,
    ThaiInstitutionCategory? initialCategory,
  }) {
    return showModalBottomSheet<ThaiInstitutionPickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ThaiInstitutionPickerSheet(
        selectedInstitution: selected,
        initialCategory: initialCategory,
      ),
    );
  }

  @override
  State<ThaiInstitutionPickerSheet> createState() =>
      _ThaiInstitutionPickerSheetState();
}

class ThaiInstitutionPickerResult {
  const ThaiInstitutionPickerResult({this.institution, this.cleared = false});

  final ThaiInstitution? institution;
  final bool cleared;
}

class _ThaiInstitutionPickerSheetState
    extends State<ThaiInstitutionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  ThaiInstitutionCategory? _selectedCategory;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStrings strings = AppStrings.of(context);
    final List<ThaiInstitution> filtered = ThaiInstitutionCatalog.filter(
      query: _query,
      category: _selectedCategory,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.tr(
                              'ธนาคารและสินเชื่อในประเทศไทย',
                              'Thai Banks, Loans & Wallets',
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.tr(
                              'เลือกจาก ${ThaiInstitutionCatalog.all.length} สถาบันการเงินและผู้ให้บริการสินเชื่อ',
                              'Choose from ${ThaiInstitutionCatalog.all.length} Thai financial institutions & lenders',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: strings.tr(
                      'ค้นหา เช่น กสิกร, SCB, เงินติดล้อ, KTC, กยศ., TrueMoney...',
                      'Search KBank, SCB, Tidlor, KTC, FINNIX, TrueMoney...',
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear_rounded),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '${strings.all} (${ThaiInstitutionCatalog.all.length})',
                        ),
                        selected: _selectedCategory == null,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = null),
                      ),
                    ),
                    for (final ThaiInstitutionCategory cat
                        in ThaiInstitutionCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            strings.isThai ? cat.labelTh : cat.labelEn,
                          ),
                          selected: _selectedCategory == cat,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.selectedInstitution != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        const ThaiInstitutionPickerResult(cleared: true),
                      ),
                      icon: const Icon(Icons.layers_clear_outlined, size: 18),
                      label: Text(
                        strings.tr(
                          'ไม่ระบุสถาบัน (ใช้ไอคอนทั่วไป)',
                          'Clear institution (use generic icon)',
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.search_off_rounded,
                                size: 42,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                strings.tr(
                                  'ไม่พบธนาคารหรือสินเชื่อที่ค้นหา สามารถพิมพ์ชื่อสถาบันเองได้เลย',
                                  'No matching institution found. You can still type a custom name.',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final bool twoColumns = constraints.maxWidth >= 560;
                              if (twoColumns) {
                                return GridView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    6,
                                    20,
                                    28,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        mainAxisExtent: 76,
                                      ),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, int index) =>
                                      _buildItemCard(
                                        filtered[index],
                                        theme,
                                        strings,
                                      ),
                                );
                              }
                              return ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  6,
                                  20,
                                  28,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, int index) => _buildItemCard(
                                  filtered[index],
                                  theme,
                                  strings,
                                ),
                              );
                            },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemCard(
    ThaiInstitution item,
    ThemeData theme,
    AppStrings strings,
  ) {
    final bool isSelected = widget.selectedInstitution?.id == item.id;
    final Color brandColor = AppColors.fromHex(item.primaryHex);

    return Material(
      color: isSelected
          ? brandColor.withAlpha(24)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pop(
          ThaiInstitutionPickerResult(institution: item),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? brandColor
                  : theme.colorScheme.outlineVariant.withAlpha(110),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: <Widget>[
              ThaiInstitutionBadge(institution: item, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      strings.isThai ? item.nameTh : item.nameEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.isThai
                          ? '${item.category.labelTh} · ${item.nameEn}'
                          : '${item.category.labelEn} · ${item.nameTh}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: brandColor, size: 22)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

