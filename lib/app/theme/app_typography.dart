import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale (Poppins). Headings stay at semibold; bold is reserved for
/// key figures.
abstract final class AppTypography {
  static TextTheme get textTheme {
    return GoogleFonts.poppinsTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: -0.6,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: -0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      ),
    );
  }

  static const _tabular = [FontFeature.tabularFigures()];

  /// Primary figure on a metric card (e.g. today's sales).
  static TextStyle get metricLarge => GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.6,
    fontFeatures: _tabular,
  );

  /// Secondary figures: totals in panels and summaries.
  static TextStyle get metricMedium => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );

  /// Amounts in list rows and tables.
  static TextStyle get amount => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFeatures: _tabular,
  );

  /// Small uppercase label above a figure or a navigation section.
  static TextStyle get overline => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.8,
  );
}
