import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/pending_sale_request.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_outcome.dart';
import '../../domain/entities/sale_request_exception.dart';
import '../../domain/entities/sale_payment_summary.dart';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_remote_datasource.dart';

class SalesRepositoryImpl implements SaleRepository {
  SalesRepositoryImpl(this._remoteDataSource);

  final SalesRemoteDataSource _remoteDataSource;

  @override
  Future<SaleSubmission> submitSale(PendingSaleRequest request) async {
    try {
      return await switch (request.draft.kind) {
        SaleRequestKind.standard => _remoteDataSource.createSaleIdempotent(
          request,
        ),
        SaleRequestKind.credit =>
          _remoteDataSource.createCreditSaleWithInitialPayment(request),
      };
    } catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<String?> findSaleByIdempotencyKey(String idempotencyKey) async {
    try {
      return await _remoteDataSource.findSaleByIdempotencyKey(idempotencyKey);
    } catch (error) {
      throw _translate(error);
    }
  }

  /// A five-character SQLSTATE, e.g. P0001, SMD01, 42501.
  static final _sqlState = RegExp(r'^[0-9A-Z]{5}$');

  /// The credit function reports a key conflict with this fixed message
  /// (its SQLSTATE is the generic P0001).
  static const _creditKeyConflict =
      'Idempotency key has already been used with a different credit-sale '
      'request';

  /// Whether the database answered (and so rolled back) or the outcome is
  /// unknown.
  ///
  /// PostgREST runs each call in one transaction and commits only on
  /// success, so a response carrying a SQLSTATE or a PGRST code means
  /// nothing was recorded. Anything else (no response, a gateway error
  /// whose "code" is just an HTTP status, an unreadable success body) may
  /// follow a commit, so it is unknown.
  static SaleRequestException _translate(Object error) {
    if (error is SaleRequestException) return error;
    if (error is! PostgrestException) {
      return const SaleRequestException(SaleRequestErrorKind.outcomeUnknown);
    }

    final code = error.code ?? '';
    if (code == 'PGRST202' || code == '42883') {
      // The function does not exist: the database is not updated yet.
      return SaleRequestException(
        SaleRequestErrorKind.serviceUnavailable,
        code: code,
      );
    }
    if (!_sqlState.hasMatch(code) && !code.startsWith('PGRST')) {
      return SaleRequestException(
        SaleRequestErrorKind.outcomeUnknown,
        code: code,
      );
    }

    final kind = switch (code) {
      'SMD01' => SaleRequestErrorKind.discountRefused,
      'SMI01' => SaleRequestErrorKind.keyConflict,
      'P0001' when error.message.startsWith(_creditKeyConflict) =>
        SaleRequestErrorKind.creditKeyConflict,
      _ => SaleRequestErrorKind.rejected,
    };
    return SaleRequestException(kind, code: code, serverMessage: error.message);
  }

  @override
  Future<List<Sale>> getSales() {
    return _remoteDataSource.getSales();
  }

  @override
  Future<Sale> getSaleById(String id) {
    return _remoteDataSource.getSaleById(id);
  }

  @override
  Future<SalePaymentSummary> getSalePaymentSummary(String saleId) {
    return _remoteDataSource.getSalePaymentSummary(saleId);
  }
}
