const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `8 Oct 2026`, formatted as given (no time zone conversion), so date-only
/// values such as expense and purchase dates keep their calendar day. Pass
/// `toLocal()` for timestamps.
String formatShortDate(DateTime date) {
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// `2:05 PM`, in local time.
String formatClockTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

/// `8 Oct, 2:05 PM` this year, `8 Oct 2025, 2:05 PM` otherwise; local time.
String formatDateTime(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final day = local.year == (now ?? DateTime.now()).year
      ? '${local.day} ${_months[local.month - 1]}'
      : formatShortDate(local);
  return '$day, ${formatClockTime(local)}';
}
