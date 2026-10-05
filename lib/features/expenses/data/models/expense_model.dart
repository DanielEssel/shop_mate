import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_payment_method.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    required super.id,
    required super.category,
    required super.amount,
    required super.paymentMethod,
    required super.expenseDate,
    required super.createdAt,
    required super.updatedAt,
    super.reference,
    super.note,
    super.createdBy,
  });

  /// Columns read from `public.expenses`; shop and idempotency columns are
  /// deliberately not exposed to the app.
  static const selectColumns =
      'id, category, amount, payment_method, expense_date, reference, note, '
      'created_by, created_at, updated_at';

  factory ExpenseModel.fromRow(Map<String, Object?> row) {
    final categoryCode = _string(row, 'category');
    final methodCode = _string(row, 'payment_method');

    return ExpenseModel(
      id: _string(row, 'id'),
      category: ExpenseCategory.values.firstWhere(
        (category) => category.code == categoryCode,
        orElse: () =>
            throw FormatException('Unknown expense category: $categoryCode.'),
      ),
      amount: _number(row, 'amount'),
      paymentMethod: ExpensePaymentMethod.values.firstWhere(
        (method) => method.code == methodCode,
        orElse: () => throw FormatException(
          'Unknown expense payment method: $methodCode.',
        ),
      ),
      expenseDate: _calendarDate(row, 'expense_date'),
      reference: _optionalString(row, 'reference'),
      note: _optionalString(row, 'note'),
      createdBy: _optionalString(row, 'created_by'),
      createdAt: _timestamp(row, 'created_at'),
      updatedAt: _timestamp(row, 'updated_at'),
    );
  }

  static String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid expense field: $field.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid expense field: $field.');
    }
    return value;
  }

  static double _number(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! num) {
      throw FormatException('Invalid expense amount: $field.');
    }
    return value.toDouble();
  }

  /// Parses a Postgres `date` (`yyyy-MM-dd`) as a local calendar date so it
  /// never shifts by a day across time zones.
  static DateTime _calendarDate(Map<String, Object?> row, String field) {
    final value = _string(row, field);
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid expense date: $field.');
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static DateTime _timestamp(Map<String, Object?> row, String field) {
    final parsed = DateTime.tryParse(_string(row, field));
    if (parsed == null) {
      throw FormatException('Invalid expense timestamp: $field.');
    }
    return parsed;
  }
}
