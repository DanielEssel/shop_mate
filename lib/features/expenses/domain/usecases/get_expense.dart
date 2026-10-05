import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class GetExpense {
  GetExpense(this._repository);

  final ExpenseRepository _repository;

  Future<Expense> call(String id) {
    return _repository.getExpenseById(id);
  }
}
