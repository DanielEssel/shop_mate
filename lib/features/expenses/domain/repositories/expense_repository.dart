import '../entities/expense.dart';
import '../entities/expense_filter.dart';
import '../entities/record_expense_request.dart';

abstract class ExpenseRepository {
  /// Records an expense and returns its id.
  Future<String> recordExpense(RecordExpenseRequest request);

  /// Expenses matching [filter], newest first, at most [limit] rows.
  Future<List<Expense>> getExpenses(ExpenseFilter filter, {required int limit});

  Future<Expense> getExpenseById(String id);
}
