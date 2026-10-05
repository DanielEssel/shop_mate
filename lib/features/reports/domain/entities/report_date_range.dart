import 'package:flutter/foundation.dart';

/// An inclusive range of local business dates (no time component).
///
/// Both ends are normalised to midnight, and [start] can never be after
/// [end].
@immutable
class ReportDateRange {
  ReportDateRange({required DateTime start, required DateTime end})
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (this.start.isAfter(this.end)) {
      throw ArgumentError('The start date must be on or before the end date.');
    }
  }

  /// A single business day.
  factory ReportDateRange.day(DateTime date) =>
      ReportDateRange(start: date, end: date);

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is ReportDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
