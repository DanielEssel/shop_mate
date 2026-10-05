import '../entities/expense_filter.dart';
import '../entities/expense_history.dart';
import '../repositories/expense_repository.dart';

class GetExpenseHistory {
  GetExpenseHistory(this._repository);

  /// Upper bound on rows loaded for one filter; narrower filters show more
  /// history without loading the whole table.
  static const maxResults = 500;

  final ExpenseRepository _repository;

  Future<ExpenseHistory> call(ExpenseFilter filter) async {
    // Fetch one extra row to know whether the result was capped.
    final expenses = await _repository.getExpenses(
      filter,
      limit: maxResults + 1,
    );

    final hasMore = expenses.length > maxResults;

    return ExpenseHistory(
      expenses: List.unmodifiable(
        hasMore ? expenses.take(maxResults) : expenses,
      ),
      hasMore: hasMore,
    );
  }
}
