import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/core/utils/date_format.dart';

void main() {
  final now = DateTime(2026, 10, 8, 9);

  test('clock time uses 12-hour time with AM/PM', () {
    expect(formatClockTime(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    expect(formatClockTime(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    expect(formatClockTime(DateTime(2026, 1, 1, 14, 30)), '2:30 PM');
  });

  test('short date', () {
    expect(formatShortDate(DateTime(2026, 10, 8)), '8 Oct 2026');
  });

  test('date and time omit the year only for the current year', () {
    expect(
      formatDateTime(DateTime(2026, 3, 4, 14, 5), now: now),
      '4 Mar, 2:05 PM',
    );
    expect(
      formatDateTime(DateTime(2025, 12, 31, 9, 0), now: now),
      '31 Dec 2025, 9:00 AM',
    );
  });
}
