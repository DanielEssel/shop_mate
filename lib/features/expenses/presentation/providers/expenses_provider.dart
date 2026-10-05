import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/expense_remote_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_filter.dart';
import '../../domain/entities/expense_history.dart';
import '../../domain/entities/expense_payment_method.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/get_expense.dart';
import '../../domain/usecases/get_expense_history.dart';
import '../../domain/usecases/record_expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final dataSource = ExpenseRemoteDataSource(SupabaseService.client);

  return ExpenseRepositoryImpl(dataSource);
});

final recordExpenseProvider = Provider<RecordExpense>((ref) {
  return RecordExpense(ref.read(expenseRepositoryProvider));
});

final getExpenseHistoryProvider = Provider<GetExpenseHistory>((ref) {
  return GetExpenseHistory(ref.read(expenseRepositoryProvider));
});

final getExpenseProvider = Provider<GetExpense>((ref) {
  return GetExpense(ref.read(expenseRepositoryProvider));
});

/// Filters for the Expense History screen. Disposed with the screen, so the
/// filters reset each time the screen is opened.
final expenseFilterProvider =
    NotifierProvider.autoDispose<ExpenseFilterNotifier, ExpenseFilter>(
      ExpenseFilterNotifier.new,
    );

class ExpenseFilterNotifier extends Notifier<ExpenseFilter> {
  @override
  ExpenseFilter build() => const ExpenseFilter();

  /// Sets the date range; callers must keep [from] on or before [to].
  void setDateRange({DateTime? from, DateTime? to}) {
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('The start date must be on or before the end date.');
    }

    state = ExpenseFilter(
      dateFrom: from,
      dateTo: to,
      category: state.category,
      paymentMethod: state.paymentMethod,
    );
  }

  void setCategory(ExpenseCategory? category) {
    state = ExpenseFilter(
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      category: category,
      paymentMethod: state.paymentMethod,
    );
  }

  void setPaymentMethod(ExpensePaymentMethod? paymentMethod) {
    state = ExpenseFilter(
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      category: state.category,
      paymentMethod: paymentMethod,
    );
  }

  void clear() {
    state = const ExpenseFilter();
  }
}

/// Expense history for the current filters; reloads whenever they change.
final expenseHistoryProvider = FutureProvider.autoDispose<ExpenseHistory>((
  ref,
) {
  final filter = ref.watch(expenseFilterProvider);

  return ref.read(getExpenseHistoryProvider).call(filter);
});

final expenseProvider = FutureProvider.autoDispose.family<Expense, String>((
  ref,
  id,
) {
  return ref.read(getExpenseProvider).call(id);
});
