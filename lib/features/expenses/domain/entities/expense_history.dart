import 'package:flutter/foundation.dart';

import 'expense.dart';

/// The expenses loaded for one filter, newest first.
@immutable
class ExpenseHistory {
  const ExpenseHistory({required this.expenses, required this.hasMore});

  final List<Expense> expenses;

  /// True when more expenses match the filter than were loaded.
  final bool hasMore;

  /// Sum of the loaded expenses, added in whole cents to avoid
  /// floating-point drift.
  double get totalAmount =>
      expenses.fold<int>(
        0,
        (sum, expense) => sum + (expense.amount * 100).round(),
      ) /
      100;
}
