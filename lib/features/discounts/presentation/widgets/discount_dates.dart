import 'package:flutter/material.dart';

/// The discount ends at the END of the day the owner picks: the stored
/// moment is local midnight after that day.
DateTime discountEndsAtForDay(DateTime day) {
  return DateTime(day.year, day.month, day.day + 1);
}

/// The day the owner picked for a stored [endsAt].
DateTime discountEndDayOf(DateTime endsAt) {
  final last = endsAt.toLocal().subtract(const Duration(microseconds: 1));
  return DateTime(last.year, last.month, last.day);
}

/// e.g. `Oct 20, 2026` (medium dates omit the year otherwise).
String formatDiscountDay(BuildContext context, DateTime day) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(day)}, ${day.year}';
}

String formatDiscountEndDay(BuildContext context, DateTime endsAt) {
  return 'End of ${formatDiscountDay(context, discountEndDayOf(endsAt))}';
}
