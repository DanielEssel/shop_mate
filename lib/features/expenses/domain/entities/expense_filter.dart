import 'package:flutter/foundation.dart';

import 'expense_category.dart';
import 'expense_payment_method.dart';

/// Filters for expense history. A null field means "no restriction".
@immutable
class ExpenseFilter {
  const ExpenseFilter({
    this.dateFrom,
    this.dateTo,
    this.category,
    this.paymentMethod,
  });

  /// Inclusive start date (local calendar date).
  final DateTime? dateFrom;

  /// Inclusive end date (local calendar date).
  final DateTime? dateTo;
  final ExpenseCategory? category;
  final ExpensePaymentMethod? paymentMethod;

  bool get isEmpty =>
      dateFrom == null &&
      dateTo == null &&
      category == null &&
      paymentMethod == null;

  @override
  bool operator ==(Object other) {
    return other is ExpenseFilter &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        other.category == category &&
        other.paymentMethod == paymentMethod;
  }

  @override
  int get hashCode => Object.hash(dateFrom, dateTo, category, paymentMethod);
}
