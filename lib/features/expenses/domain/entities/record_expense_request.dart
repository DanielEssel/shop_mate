import 'package:flutter/foundation.dart';

import 'expense_category.dart';
import 'expense_payment_method.dart';

/// A request to record one expense. The shop is resolved by the database
/// from the caller's active shop, so it is intentionally not part of this
/// request.
@immutable
class RecordExpenseRequest {
  const RecordExpenseRequest({
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.expenseDate,
    required this.idempotencyKey,
    this.reference,
    this.note,
  });

  final ExpenseCategory category;
  final double amount;
  final ExpensePaymentMethod paymentMethod;

  /// Calendar date of the expense; only the year, month and day are used.
  final DateTime expenseDate;
  final String idempotencyKey;
  final String? reference;
  final String? note;
}
