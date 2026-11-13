import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle tabularStyle(TextStyle base) {
    return base.copyWith(fontFeatures: tabularFigures);
  }

  static ThemeData light() {
    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryEmerald,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCCFBF1),
      onPrimaryContainer: Color(0xFF042F2E),
      secondary: AppColors.accentGold,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFEF3C7),
      onSecondaryContainer: Color(0xFF78350F),
      error: AppColors.expense,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      outline: AppColors.lightBorder,
      outlineVariant: Color(0xFFCBD5E1),
    );
    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.lightBackground,
      surfaceSubtle: AppColors.lightSurfaceSubtle,
      borderColor: AppColors.lightBorder,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      snackBarBackground: AppColors.lightTextPrimary,
      snackBarTextColor: Colors.white,
      primaryAccent: AppColors.primaryEmerald,
      buttonForegroundOnPrimary: Colors.white,
      errorBorderColor: AppColors.expense,
    );
  }

  static ThemeData dark() {
    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryEmeraldLight,
      onPrimary: Color(0xFF042F2E),
      primaryContainer: Color(0xFF115E59),
      onPrimaryContainer: Color(0xFFCCFBF1),
      secondary: AppColors.accentGoldLight,
      onSecondary: Color(0xFF451A03),
      secondaryContainer: Color(0xFF78350F),
      onSecondaryContainer: Color(0xFFFEF3C7),
      error: AppColors.expenseDark,
      onError: Color(0xFF4C0519),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorder,
      outlineVariant: Color(0xFF334155),
    );
    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.darkBackground,
      surfaceSubtle: AppColors.darkSurfaceSubtle,
      borderColor: AppColors.darkBorder,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      snackBarBackground: AppColors.darkSurfaceSubtle,
      snackBarTextColor: AppColors.darkTextPrimary,
      primaryAccent: AppColors.primaryEmeraldLight,
      buttonForegroundOnPrimary: const Color(0xFF042F2E),
      errorBorderColor: AppColors.expenseDark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color surfaceSubtle,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color snackBarBackground,
    required Color snackBarTextColor,
    required Color primaryAccent,
    required Color buttonForegroundOnPrimary,
    required Color errorBorderColor,
  }) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    final TextTheme rawBase = isDark
        ? ThemeData.dark(useMaterial3: true).textTheme
        : ThemeData.light(useMaterial3: true).textTheme;

    final TextTheme notoTheme = GoogleFonts.notoSansThaiTextTheme(rawBase).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final TextTheme balancedTextTheme = notoTheme.copyWith(
      headlineSmall: notoTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.32,
      ),
      titleLarge: notoTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: notoTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.38,
      ),
      titleSmall: notoTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.38,
      ),
      bodyLarge: notoTheme.bodyLarge?.copyWith(
        fontSize: 15.5,
        height: 1.45,
      ),
      bodyMedium: notoTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.42,
      ),
      bodySmall: notoTheme.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.4,
      ),
      labelLarge: notoTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      labelMedium: notoTheme.labelMedium?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      labelSmall: notoTheme.labelSmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: balancedTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: balancedTextTheme.titleLarge?.copyWith(
          color: textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.income.withAlpha(isDark ? 42 : 34),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 8,
        shadowColor: Colors.black.withAlpha(isDark ? 40 : 14),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return balancedTextTheme.labelSmall?.copyWith(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primaryAccent : textSecondary,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryAccent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: errorBorderColor),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: buttonForegroundOnPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: balancedTextTheme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: borderColor),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: balancedTextTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: balancedTextTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 10,
        iconColor: primaryAccent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: snackBarBackground,
        contentTextStyle: balancedTextTheme.bodyMedium?.copyWith(
          color: snackBarTextColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
