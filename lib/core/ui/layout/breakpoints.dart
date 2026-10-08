import 'package:flutter/widgets.dart';

import '../../../app/theme/app_spacing.dart';

/// Width classes. Layout decisions use these instead of ad-hoc thresholds.
///
/// Decide from the width actually available to the widget (a
/// `LayoutBuilder` constraint) for content, and from the window width for
/// app-level chrome such as navigation.
enum WindowSize {
  /// Phones: under 600.
  compact,

  /// Tablets and narrow windows: 600–1023.
  medium,

  /// Desktop: 1024–1439.
  expanded,

  /// Large desktop: 1440 and up.
  large;

  bool get isCompact => this == compact;

  /// Medium or wider.
  bool get isAtLeastMedium => index >= medium.index;

  /// Expanded or wider.
  bool get isAtLeastExpanded => index >= expanded.index;
}

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double large = 1440;

  /// Below this a phone is "small": tighten gutters and stack more.
  static const double smallPhone = 360;

  static WindowSize of(double width) {
    if (width >= large) return WindowSize.large;
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }

  /// The window's size class.
  static WindowSize ofWindow(BuildContext context) {
    return of(MediaQuery.sizeOf(context).width);
  }

  static bool isSmallPhone(double width) => width < smallPhone;

  /// Horizontal page padding for content of [width].
  static double gutter(double width) {
    if (width < smallPhone) return AppSpacing.md;
    return switch (of(width)) {
      WindowSize.compact => AppSpacing.lg,
      WindowSize.medium => AppSpacing.xxl,
      WindowSize.expanded || WindowSize.large => AppSpacing.xxxl,
    };
  }

  /// Horizontal padding that applies [gutter] and centres content no wider
  /// than [maxWidth].
  static double pagePadding(double width, {double maxWidth = 1280}) {
    final gutter = Breakpoints.gutter(width);
    final centred = (width - maxWidth) / 2;
    return centred > gutter ? centred : gutter;
  }
}

/// Content max widths by content type.
abstract final class ContentWidth {
  /// Forms and reading content.
  static const double form = 760;

  /// Dashboards and mixed content.
  static const double standard = 1280;

  /// Data-heavy tables.
  static const double wide = 1600;
}
