/// Formats an amount as Ghana cedis with thousands separators,
/// e.g. `1000` -> `GHS 1,000.00`.
String formatGhs(double amount) {
  final cents = (amount * 100).round();
  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  final whole = (absolute ~/ 100).toString();
  final fraction = (absolute % 100).toString().padLeft(2, '0');

  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  return 'GHS $sign$grouped.$fraction';
}
