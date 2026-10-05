import '../entities/record_expense_request.dart';
import '../repositories/expense_repository.dart';

class RecordExpense {
  RecordExpense(this._repository);

  final ExpenseRepository _repository;

  Future<String> call(RecordExpenseRequest request) {
    return _repository.recordExpense(request);
  }
}
