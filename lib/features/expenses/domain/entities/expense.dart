import 'package:flutter/foundation.dart';

import 'expense_category.dart';
import 'expense_payment_method.dart';

@immutable
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.reference,
    this.note,
    this.createdBy,
  });

  final String id;
  final ExpenseCategory category;
  final double amount;
  final ExpensePaymentMethod paymentMethod;

  /// Calendar date of the expense (local date, no time component).
  final DateTime expenseDate;
  final String? reference;
  final String? note;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
