import '../entities/pending_sale_request.dart';

/// The device's record of the sale whose outcome is not yet confirmed (at
/// most one per account and shop), and of the requests set aside before
/// their outcome was known. Every call is awaited; failures throw
/// `PendingSaleStoreException`.
abstract class PendingSaleStore {
  /// The saved request for [scope], or null. An unreadable record throws
  /// (with its raw value) instead of being dropped.
  Future<PendingSaleRequest?> load(PendingSaleScope scope);

  Future<void> save(PendingSaleRequest request);

  /// Removes the pending request. Only for a request whose outcome is
  /// known (recorded, or refused on its only attempt).
  Future<void> delete(PendingSaleScope scope);

  /// Moves the pending [request] to the abandoned requests, which are
  /// kept so it can still be reconciled. The abandoned copy is written
  /// before the pending one is removed: an interruption leaves it in both,
  /// never in neither.
  Future<void> abandon(PendingSaleRequest request, DateTime abandonedAt);

  /// The same for a pending record that cannot be read: [rawValue] is
  /// kept verbatim among the abandoned requests.
  Future<void> abandonUnreadable(PendingSaleScope scope, String rawValue);

  /// The readable abandoned requests for [scope], oldest first. Unreadable
  /// entries are kept on the device but not returned.
  Future<List<AbandonedSaleRequest>> loadAbandoned(PendingSaleScope scope);

  /// Forgets an abandoned request once its outcome is known and the
  /// cashier has seen it.
  Future<void> removeAbandoned(PendingSaleScope scope, String idempotencyKey);
}
