import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/expense_filter.dart';
import '../../domain/entities/record_expense_request.dart';
import '../models/expense_model.dart';

class ExpenseRemoteDataSource {
  ExpenseRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'expenses';

  /// Expenses are only written through `record_expense`, which resolves the
  /// shop from the caller's session; no shop id is ever sent.
  Future<String> recordExpense(RecordExpenseRequest request) async {
    final response = await _client.rpc(
      'record_expense',
      params: {
        'p_category': request.category.code,
        'p_amount': request.amount,
        'p_payment_method': request.paymentMethod.code,
        'p_expense_date': _dateOnly(request.expenseDate),
        'p_reference': request.reference,
        'p_note': request.note,
        'p_idempotency_key': request.idempotencyKey,
      },
    );

    if (response is! String) {
      throw const FormatException('Invalid record expense response.');
    }

    return response;
  }

  /// Reads expenses visible to the caller. Row-level security limits rows to
  /// the caller's active shop, so no shop id is sent. All filtering, ordering
  /// and limiting happens in the database query.
  Future<List<ExpenseModel>> getExpenses(
    ExpenseFilter filter, {
    required int limit,
  }) async {
    var query = _client.from(_table).select(ExpenseModel.selectColumns);

    final dateFrom = filter.dateFrom;
    if (dateFrom != null) {
      query = query.gte('expense_date', _dateOnly(dateFrom));
    }
    final dateTo = filter.dateTo;
    if (dateTo != null) {
      query = query.lte('expense_date', _dateOnly(dateTo));
    }
    final category = filter.category;
    if (category != null) {
      query = query.eq('category', category.code);
    }
    final paymentMethod = filter.paymentMethod;
    if (paymentMethod != null) {
      query = query.eq('payment_method', paymentMethod.code);
    }

    final response = await query
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return response
        .map((row) => ExpenseModel.fromRow(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  Future<ExpenseModel> getExpenseById(String id) async {
    final response = await _client
        .from(_table)
        .select(ExpenseModel.selectColumns)
        .eq('id', id)
        .single();

    return ExpenseModel.fromRow(Map<String, Object?>.from(response));
  }

  /// Formats the local calendar date as `yyyy-MM-dd` without a UTC shift.
  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }
}
