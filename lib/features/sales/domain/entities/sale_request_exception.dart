/// Why a sale request failed, as far as the app can tell.
enum SaleRequestErrorKind {
  /// The database refused the sale (validation, stock, payment...): nothing
  /// was recorded.
  rejected,

  /// SQLSTATE SMD01: a selected-products discount would go below cost.
  discountRefused,

  /// SQLSTATE SMI01: the request key was already used for a different sale.
  keyConflict,

  /// The credit function's key conflict (it has no distinct SQLSTATE, so
  /// the data layer recognises its fixed message).
  creditKeyConflict,

  /// The idempotent sale function is missing (database not updated): the
  /// app will not fall back to the unprotected function.
  serviceUnavailable,

  /// No database answer (connection lost, gateway error, unreadable reply):
  /// the sale may or may not have been recorded.
  outcomeUnknown,
}

class SaleRequestException implements Exception {
  const SaleRequestException(this.kind, {this.code, this.serverMessage});

  final SaleRequestErrorKind kind;

  /// The SQLSTATE or HTTP status, for diagnostics.
  final String? code;

  /// The database's own message for [SaleRequestErrorKind.rejected], which
  /// the checkout already shows for non-credit sales (stock, payment...).
  final String? serverMessage;

  /// Nothing was recorded: the request can be dropped.
  bool get isDefinite => kind != SaleRequestErrorKind.outcomeUnknown;

  @override
  String toString() => 'SaleRequestException(${kind.name}, code: $code)';
}

/// The device could not read or write its saved pending sale.
class PendingSaleStoreException implements Exception {
  const PendingSaleStoreException(this.operation, {this.rawValue, this.cause});

  /// `load`, `save` or `delete`.
  final String operation;

  /// What was stored, when it could not be understood; kept for recovery.
  final String? rawValue;
  final Object? cause;

  @override
  String toString() => 'PendingSaleStoreException($operation)';
}
