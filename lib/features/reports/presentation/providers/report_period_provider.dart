import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/report_date_range.dart';

/// Quick date ranges offered on the Business Performance screen.
enum ReportPeriodPreset {
  today('Today'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  custom('Custom');

  const ReportPeriodPreset(this.label);

  final String label;
}

/// The selected preset and the inclusive local-date range it resolves to.
@immutable
class ReportPeriod {
  const ReportPeriod({required this.preset, required this.range});

  final ReportPeriodPreset preset;
  final ReportDateRange range;
}

/// Selected period for the Business Performance screen; resets to Today
/// each time the screen is opened.
final reportPeriodProvider =
    NotifierProvider.autoDispose<ReportPeriodNotifier, ReportPeriod>(
      ReportPeriodNotifier.new,
    );

class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  /// Clock used to resolve presets; replaceable in tests.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @override
  ReportPeriod build() => _resolve(ReportPeriodPreset.today);

  /// Selects a quick range ending today. Use [selectCustom] for custom.
  void selectPreset(ReportPeriodPreset preset) {
    assert(preset != ReportPeriodPreset.custom);
    state = _resolve(preset);
  }

  /// Re-resolves a quick range against the current date, so a screen left
  /// open past midnight refreshes into the new day. Custom ranges are kept.
  void refreshRelativeRange() {
    if (state.preset == ReportPeriodPreset.custom) return;
    state = _resolve(state.preset);
  }

  /// Selects a custom range; future dates are not allowed.
  void selectCustom(ReportDateRange range) {
    if (range.end.isAfter(today())) {
      throw ArgumentError('A report range cannot include future dates.');
    }
    state = ReportPeriod(preset: ReportPeriodPreset.custom, range: range);
  }

  /// Today's local calendar date.
  static DateTime today() {
    final current = now();
    return DateTime(current.year, current.month, current.day);
  }

  static ReportPeriod _resolve(ReportPeriodPreset preset) {
    final end = today();
    final days = switch (preset) {
      ReportPeriodPreset.today => 1,
      ReportPeriodPreset.last7Days => 7,
      ReportPeriodPreset.last30Days => 30,
      ReportPeriodPreset.custom => throw ArgumentError(
        'Custom ranges are selected with selectCustom.',
      ),
    };

    // Calendar arithmetic (not Duration) so daylight-saving shifts on a
    // device can never skip or repeat a date.
    final start = DateTime(end.year, end.month, end.day - (days - 1));

    return ReportPeriod(
      preset: preset,
      range: ReportDateRange(start: start, end: end),
    );
  }
}
