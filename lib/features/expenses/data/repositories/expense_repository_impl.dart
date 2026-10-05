import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_filter.dart';
import '../../domain/entities/record_expense_request.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_remote_datasource.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._remoteDataSource);

  final ExpenseRemoteDataSource _remoteDataSource;

  @override
  Future<String> recordExpense(RecordExpenseRequest request) {
    return _remoteDataSource.recordExpense(request);
  }

  @override
  Future<List<Expense>> getExpenses(
    ExpenseFilter filter, {
    required int limit,
  }) {
    return _remoteDataSource.getExpenses(filter, limit: limit);
  }

  @override
  Future<Expense> getExpenseById(String id) {
    return _remoteDataSource.getExpenseById(id);
  }
}
