import '../entities/pending_sale_request.dart';
import '../entities/recorded_sale.dart';
import '../entities/sale_outcome.dart';
import '../entities/sale_request_exception.dart';
import '../repositories/pending_sale_store.dart';
import '../repositories/sales_repository.dart';

/// Records sales at most once per request, across retries and restarts.
///
/// Lifecycle of a request (one pending per account and shop):
///  1. [submit] creates the key, SAVES the request on the device, and only
///     then sends it. If saving fails, nothing is sent.
///  2. A recorded sale (new or replayed) clears the saved request, and so
///     does a definite database refusal of the first attempt: that was the
///     only request sent (sale RPCs are never retried by the client), so
///     nothing can still be recorded.
///  3. No answer (lost connection, gateway error, unreadable reply) keeps
///     it. Nothing is resent automatically, and no new sale can start.
///  4. Recovery: [lookUpPending] asks the database for a sale recorded
///     under the key. Found: recorded. Not found: it may still be on its
///     way, so it stays saved. [retryPending] resends the SAME key and
///     payload, but only once the cashier confirms the customer has paid
///     and is waiting; the database returns the original sale if it was
///     recorded meanwhile. A refused retry keeps the request: the first
///     attempt may still arrive.
///  5. [abandonPending] sets it aside when the customer has left. That
///     cannot stop the original request, so it is never deleted: it moves
///     to the device's abandoned requests, which [reconcileAbandoned] keeps
///     looking up (never resending). Only a lookup that finds the sale, seen
///     by the cashier ([acknowledgeAbandoned]), removes one.
///
/// Different devices create different keys, so the same purchase rung up on
/// two devices is two requests; this cannot be deduplicated here.
class SubmitSale {
  SubmitSale({
    required this._repository,
    required this._store,
    required this._newKey,
    required this._now,
  });

  final SaleRepository _repository;
  final PendingSaleStore _store;
  final String Function() _newKey;
  final DateTime Function() _now;

  /// The unresolved request for [scope], if any. Throws
  /// `PendingSaleStoreException` when it cannot be read.
  Future<PendingSaleRequest?> loadPending(PendingSaleScope scope) {
    return _store.load(scope);
  }

  /// Submits a NEW sale. Refused (nothing sent) while another request for
  /// this account and shop is unresolved: that one must be resolved first.
  Future<SaleOutcome> submit(SaleDraft draft, PendingSaleScope scope) async {
    final PendingSaleRequest? existing;
    try {
      existing = await _store.load(scope);
    } on PendingSaleStoreException catch (error) {
      return SaleOutcomeNotSaved(error);
    }
    if (existing != null) return SaleOutcomeBlocked(existing);

    final request = PendingSaleRequest(
      idempotencyKey: _newKey(),
      scope: scope,
      draft: draft,
      createdAt: _now(),
    );
    try {
      await _store.save(request);
    } on PendingSaleStoreException catch (error) {
      return SaleOutcomeNotSaved(error);
    } catch (error) {
      return SaleOutcomeNotSaved(
        PendingSaleStoreException('save', cause: error),
      );
    }
    return _send(request, fromRecovery: false);
  }

  /// Resends the saved request unchanged (same key, same payload). The
  /// cashier must have confirmed the customer has paid and is waiting.
  Future<SaleOutcome?> retryPending(
    PendingSaleScope scope, {
    required bool customerConfirmedPaid,
  }) async {
    if (!customerConfirmedPaid) {
      throw ArgumentError.value(
        customerConfirmedPaid,
        'customerConfirmedPaid',
        'A retry needs the cashier to confirm the customer has paid.',
      );
    }
    final pending = await _store.load(scope);
    if (pending == null) return null;
    return _send(pending, fromRecovery: true);
  }

  /// Asks the database whether the saved request was recorded. Never
  /// creates a sale.
  Future<SaleOutcome?> lookUpPending(PendingSaleScope scope) async {
    final pending = await _store.load(scope);
    if (pending == null) return null;

    final String? saleId;
    try {
      saleId = await _repository.findSaleByIdempotencyKey(
        pending.idempotencyKey,
      );
    } catch (_) {
      return SaleOutcomeLookupFailed(pending);
    }
    if (saleId == null) return SaleOutcomeNotFound(pending);

    await _clear(scope);
    return SaleOutcomeRecorded(
      await _readBack(saleId),
      replayed: true,
      fromRecovery: true,
    );
  }

  /// Sets the unresolved request aside so a new sale can start. It is kept
  /// (key and payload) among the abandoned requests, never deleted. Throws
  /// `PendingSaleStoreException` if the device cannot do this; the request
  /// then stays pending.
  Future<void> abandonPending(PendingSaleScope scope) async {
    final pending = await _store.load(scope);
    if (pending == null) return;
    await _store.abandon(pending, _now());
  }

  /// Sets aside a saved record that cannot be read, kept verbatim.
  Future<void> abandonUnreadable(PendingSaleScope scope, String rawValue) =>
      _store.abandonUnreadable(scope, rawValue);

  /// Looks up every abandoned request (read only; nothing is resent) and
  /// returns those recorded after all. They stay saved until
  /// [acknowledgeAbandoned]. Requests not found, or whose lookup failed,
  /// stay saved and are looked up again next time.
  Future<List<AbandonedSaleRecorded>> reconcileAbandoned(
    PendingSaleScope scope,
  ) async {
    final List<AbandonedSaleRequest> abandoned;
    try {
      abandoned = await _store.loadAbandoned(scope);
    } catch (_) {
      return const [];
    }
    final recorded = <AbandonedSaleRecorded>[];
    for (final request in abandoned) {
      final String? saleId;
      try {
        saleId = await _repository.findSaleByIdempotencyKey(
          request.request.idempotencyKey,
        );
      } catch (_) {
        continue;
      }
      if (saleId != null) {
        recorded.add(AbandonedSaleRecorded(request, await _readBack(saleId)));
      }
    }
    return recorded;
  }

  /// The cashier has seen that an abandoned request was recorded.
  Future<void> acknowledgeAbandoned(
    PendingSaleScope scope,
    String idempotencyKey,
  ) => _store.removeAbandoned(scope, idempotencyKey);

  Future<SaleOutcome> _send(
    PendingSaleRequest request, {
    required bool fromRecovery,
  }) async {
    final SaleSubmission submission;
    try {
      submission = await _repository.submitSale(request);
    } on SaleRequestException catch (error) {
      if (!error.isDefinite) return SaleOutcomeUnknown(request);
      // A refused retry proves only that this attempt recorded nothing.
      if (fromRecovery) return SaleOutcomeRejected(error, requestKept: true);
      await _clear(request.scope);
      return SaleOutcomeRejected(error);
    } catch (_) {
      // Anything unexpected is treated as no answer.
      return SaleOutcomeUnknown(request);
    }

    // Recorded: the outcome is known even if the read-back fails.
    await _clear(request.scope);
    return SaleOutcomeRecorded(
      await _readBack(submission.saleId),
      replayed: submission.replayed,
      fromRecovery: fromRecovery,
    );
  }

  /// Clears a resolved request. If the device cannot remove it, it stays
  /// saved and the next lookup resolves it again (it is recorded or was
  /// refused), so this never undoes a result.
  Future<void> _clear(PendingSaleScope scope) async {
    try {
      await _store.delete(scope);
    } catch (_) {}
  }

  /// The recorded sale for the receipt; never resubmits when this fails.
  Future<RecordedSale> _readBack(String saleId) async {
    try {
      return RecordedSale(
        saleId: saleId,
        sale: await _repository.getSaleById(saleId),
      );
    } catch (_) {
      return RecordedSale(saleId: saleId);
    }
  }
}
