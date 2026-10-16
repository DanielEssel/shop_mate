import 'package:flutter/foundation.dart';

/// A discount percentage held exactly, as hundredths of a percent
/// ([basisPoints]): 1 is 0.01% and 9999 is 99.99%, the range the database
/// accepts. No floating-point value is ever used for it.
@immutable
class DiscountPercentage {
  const DiscountPercentage._(this.basisPoints);

  /// Throws [ArgumentError] outside 1..9999.
  factory DiscountPercentage.fromBasisPoints(int basisPoints) {
    if (basisPoints < minBasisPoints || basisPoints > maxBasisPoints) {
      throw ArgumentError.value(basisPoints, 'basisPoints');
    }
    return DiscountPercentage._(basisPoints);
  }

  static const minBasisPoints = 1;
  static const maxBasisPoints = 9999;

  /// Hundredths of a percent.
  final int basisPoints;

  static final _number = RegExp(r'^\d+(\.\d+)?$');

  /// Form validator: null when [input] is a valid percentage.
  static String? validate(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return 'Enter a discount percentage.';

    if (text.startsWith('-')) {
      return _number.hasMatch(text.substring(1))
          ? 'The discount must be at least 0.01%.'
          : 'Enter a number such as 10 or 12.5.';
    }
    if (!_number.hasMatch(text)) return 'Enter a number such as 10 or 12.5.';

    final parts = text.split('.');
    if (parts.length == 2 && parts[1].length > 2) {
      return 'Use at most two decimal places.';
    }

    final basisPoints = _basisPoints(parts);
    if (basisPoints == null || basisPoints > maxBasisPoints) {
      return 'The discount must be below 100%.';
    }
    if (basisPoints < minBasisPoints) {
      return 'The discount must be at least 0.01%.';
    }
    return null;
  }

  /// The percentage in [input], or null when [validate] would reject it.
  static DiscountPercentage? tryParse(String? input) {
    if (validate(input) != null) return null;
    final parts = input!.trim().split('.');
    return DiscountPercentage._(_basisPoints(parts)!);
  }

  /// The database's numeric value (a JSON number or string). Throws
  /// [FormatException] when it is not a valid percentage.
  factory DiscountPercentage.fromDatabase(Object? value) {
    final text = switch (value) {
      final int number => number.toString(),
      // Dart prints the shortest exact form (12.5, 0.01, 99.99).
      final double number => number.toString(),
      final String text => text,
      _ => throw const FormatException('Invalid discount percentage.'),
    };
    final normalized = _trimDatabaseZeros(text);
    final parsed = tryParse(normalized);
    if (parsed == null) {
      throw const FormatException('Invalid discount percentage.');
    }
    return parsed;
  }

  /// Exact decimal text for the database, e.g. `12.50`.
  String get databaseValue =>
      '${basisPoints ~/ 100}.${(basisPoints % 100).toString().padLeft(2, '0')}';

  /// For forms: `10`, `12.5`, `0.01`.
  String get inputText {
    final whole = basisPoints ~/ 100;
    final fraction = basisPoints % 100;
    if (fraction == 0) return '$whole';
    if (fraction % 10 == 0) return '$whole.${fraction ~/ 10}';
    return '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  /// For display: `10%`, `12.5%`.
  String get label => '$inputText%';

  static int? _basisPoints(List<String> parts) {
    final whole = parts[0];
    // More than three digits is far above 100%.
    if (whole.length > 3) return null;
    final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return int.parse(whole) * 100 + int.parse(fraction);
  }

  /// The database may send `12.50` or `10.00`; drop zeros beyond two
  /// decimals (e.g. `12.500`) so they parse like the form does.
  static String _trimDatabaseZeros(String text) {
    final dot = text.indexOf('.');
    if (dot < 0) return text;
    var end = text.length;
    while (end > dot + 3 && text[end - 1] == '0') {
      end--;
    }
    return text.substring(0, end);
  }

  @override
  bool operator ==(Object other) =>
      other is DiscountPercentage && other.basisPoints == basisPoints;

  @override
  int get hashCode => basisPoints.hashCode;

  @override
  String toString() => 'DiscountPercentage($label)';
}
