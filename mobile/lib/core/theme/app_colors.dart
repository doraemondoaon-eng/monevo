import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand Primary: Deep Emerald & Teal Luxury
  static const Color primaryEmerald = Color(0xFF0D9488);
  static const Color primaryEmeraldDark = Color(0xFF0F766E);
  static const Color primaryEmeraldLight = Color(0xFF14B8A6);
  static const Color accentGold = Color(0xFFD97706);
  static const Color accentGoldLight = Color(0xFFF59E0B);

  // Hero Card Subtle Banking Surface (Minimalist, Low-Contrast Gradient)
  static const Color heroStart = Color(0xFF0B3B36);
  static const Color heroMiddle = Color(0xFF0D4740);
  static const Color heroEnd = Color(0xFF0F524B);

  // Semantic Financial Colors
  static const Color income = Color(0xFF10B981);
  static const Color incomeDark = Color(0xFF34D399);
  static const Color expense = Color(0xFFF43F5E);
  static const Color expenseDark = Color(0xFFFB7185);
  static const Color transfer = Color(0xFF3B82F6);
  static const Color transferDark = Color(0xFF60A5FA);
  static const Color warning = Color(0xFFF59E0B);

  // Light Mode Surfaces
  static const Color lightBackground = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFEEF2F6);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Mode Surfaces
  static const Color darkBackground = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceSubtle = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  /// Preset selectable colors for accounts and categories (`#RRGGBB`).
  static const List<String> presetHexColors = <String>[
    '#0D9488',
    '#10B981',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#F43F5E',
    '#F97316',
    '#F59E0B',
    '#84CC16',
    '#06B6D4',
    '#64748B',
  ];

  /// Parses `#RRGGBB` or `RRGGBB` into a [Color] with a safe fallback.
  static Color fromHex(String? hexString, {Color fallback = primaryEmerald}) {
    if (hexString == null || hexString.trim().isEmpty) {
      return fallback;
    }
    final String cleaned = hexString.trim().replaceFirst('#', '');
    if (cleaned.length == 6) {
      final int? rgb = int.tryParse('FF$cleaned', radix: 16);
      if (rgb != null) {
        return Color(rgb);
      }
    } else if (cleaned.length == 8) {
      final int? argb = int.tryParse(cleaned, radix: 16);
      if (argb != null) {
        return Color(argb);
      }
    }
    return fallback;
  }

  /// Converts a [Color] to `#RRGGBB`.
  static String toHex(Color color) {
    final int r = (color.r * 255.0).round() & 0xff;
    final int g = (color.g * 255.0).round() & 0xff;
    final int b = (color.b * 255.0).round() & 0xff;
    final String rh = r.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String gh = g.toRadixString(16).padLeft(2, '0').toUpperCase();
    final String bh = b.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$rh$gh$bh';
  }
}
