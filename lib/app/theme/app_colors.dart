import 'package:flutter/material.dart';

/// ShopMate palette.
///
/// Green is for action, selection, brand and positive states. Neutral
/// surfaces are the workspace, charcoal is primary text, grey is secondary
/// information. Amber, red and blue are semantic states only.
abstract final class AppColors {
  // ─────────────────────────────────────────────
  // BRAND
  // ─────────────────────────────────────────────

  static const primary = Color(0xFF087F5B);
  static const primaryDark = Color(0xFF05634A);

  /// Deep forest green: brand panels (auth hero) and dark accents.
  static const primaryDeep = Color(0xFF052E22);

  /// Fresh green for accents that sit on [primaryDeep].
  static const primaryBright = Color(0xFF3DD68C);

  /// Tint for selected navigation, chips and positive highlights.
  static const primarySoft = Color(0xFFE3F3EC);

  /// Barely-there green surface for positive panels.
  static const primarySurface = Color(0xFFF1F8F5);

  /// Kept for existing screens; same as [primarySoft].
  static const primaryLight = primarySoft;

  // ─────────────────────────────────────────────
  // SURFACES
  // ─────────────────────────────────────────────

  static const background = Color(0xFFF6F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F2F1);
  static const surfaceSubtle = Color(0xFFF9FAF9);

  // ─────────────────────────────────────────────
  // TEXT
  // ─────────────────────────────────────────────

  static const textPrimary = Color(0xFF14191A);
  static const textSecondary = Color(0xFF5A625F);
  static const textMuted = Color(0xFF878F8C);

  // Text used on primary-colored surfaces.
  static const textOnPrimary = Color(0xFFFFFFFF);

  // ─────────────────────────────────────────────
  // BORDERS
  // ─────────────────────────────────────────────

  static const border = Color(0xFFE4E8E6);
  static const borderStrong = Color(0xFFD2D8D5);

  // ─────────────────────────────────────────────
  // SEMANTIC
  // ─────────────────────────────────────────────

  static const success = Color(0xFF16803C);
  static const successLight = Color(0xFFE8F5EC);

  static const warning = Color(0xFFB45309);
  static const warningLight = Color(0xFFFFF4E0);

  static const danger = Color(0xFFC8372D);
  static const dangerLight = Color(0xFFFDECEA);

  /// Kept for existing screens; same as [danger].
  static const error = danger;
  static const errorLight = dangerLight;

  static const info = Color(0xFF2563EB);
  static const infoLight = Color(0xFFEBF2FF);

  // ─────────────────────────────────────────────
  // DARK MODE FOUNDATION (not enabled)
  // ─────────────────────────────────────────────

  static const darkBackground = Color(0xFF0F1113);
  static const darkSurface = Color(0xFF181B1F);
  static const darkSurfaceMuted = Color(0xFF22262B);

  static const darkTextPrimary = Color(0xFFF5F7F9);
  static const darkTextSecondary = Color(0xFFB4BAC2);
  static const darkBorder = Color(0xFF30353B);
}
