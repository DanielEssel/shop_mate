import 'package:flutter/material.dart';

abstract final class AppColors {
  // ─────────────────────────────────────────────
  // BRAND
  // ─────────────────────────────────────────────

  static const primary = Color(0xFF087F5B);
  static const primaryDark = Color(0xFF056044);
  static const primaryLight = Color(0xFFE7F5EF);

  // ─────────────────────────────────────────────
  // LIGHT SURFACES
  // ─────────────────────────────────────────────

  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F3F5);
  static const surfaceSubtle = Color(0xFFF8F9FA);

  // ─────────────────────────────────────────────
  // TEXT
  // ─────────────────────────────────────────────

  static const textPrimary = Color(0xFF17191C);
  static const textSecondary = Color(0xFF5F6368);
  static const textMuted = Color(0xFF8B9097);

  // Text used on primary-colored surfaces.
  static const textOnPrimary = Color(0xFFFFFFFF);

  // ─────────────────────────────────────────────
  // BORDERS
  // ─────────────────────────────────────────────

  static const border = Color(0xFFE4E7EB);
  static const borderStrong = Color(0xFFD5D9DE);

  // ─────────────────────────────────────────────
  // SEMANTIC
  // ─────────────────────────────────────────────

  static const success = Color(0xFF16803C);
  static const successLight = Color(0xFFEAF7EE);

  static const warning = Color(0xFFB7791F);
  static const warningLight = Color(0xFFFFF7E6);

  static const error = Color(0xFFD64545);
  static const errorLight = Color(0xFFFDECEC);

  static const info = Color(0xFF2563EB);
  static const infoLight = Color(0xFFEFF6FF);

  // ─────────────────────────────────────────────
  // DARK MODE FOUNDATION
  // ─────────────────────────────────────────────

  static const darkBackground = Color(0xFF0F1113);
  static const darkSurface = Color(0xFF181B1F);
  static const darkSurfaceMuted = Color(0xFF22262B);

  static const darkTextPrimary = Color(0xFFF5F7F9);
  static const darkTextSecondary = Color(0xFFB4BAC2);
  static const darkBorder = Color(0xFF30353B);
}