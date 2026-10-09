/// Count formatting shared by the report screens.
library;

/// Formats a whole number with thousands separators, e.g. `12345` -> `12,345`.
String formatReportCount(int value) {
  final sign = value < 0 ? '-' : '';
  final grouped = value.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  return '$sign$grouped';
}

String pluralReportCount(int count, String singular, String plural) {
  return '${formatReportCount(count)} ${count == 1 ? singular : plural}';
}
