import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/pending_sale_request.dart';
import '../../domain/entities/sale_outcome.dart';
import '../../domain/entities/sale_request_exception.dart';
import 'sales_provider.dart';

enum PendingSalePhase {
  /// Nothing unresolved: a new sale can be submitted.
  none,

  /// A submitted sale's outcome is not confirmed yet.
  pending,

  /// A saved sale exists but could not be read.
  unreadable,
}

/// The current account and shop's unresolved sale, if any.
@immutable
class PendingSaleState {
  const PendingSaleState({
    required this.phase,
    this.pending,
    this.unreadableValue,
    this.busy = false,
    this.lookedUpNotFound = false,
    this.lookupFailed = false,
  });

  const PendingSaleState.none() : this(phase: PendingSalePhase.none);

  final PendingSalePhase phase;
  final PendingSaleRequest? pending;

  /// The unreadable record as saved, kept for support and recovery.
  final String? unreadableValue;

  /// A submission, lookup or retry is running.
  final bool busy;

  /// A lookup in this session found no recorded sale for [pending].
  final bool lookedUpNotFound;

  /// The last lookup in this session could not reach the database.
  final bool lookupFailed;

  /// New sales wait until this is resolved.
  bool get blocksCheckout => phase != PendingSalePhase.none;

  /// It can be set aside (kept, never deleted) once a lookup has been tried,
  /// or when the saved record is unreadable but its value is known.
  bool get canAbandon => switch (phase) {
    PendingSalePhase.pending => lookedUpNotFound || lookupFailed,
    PendingSalePhase.unreadable => unreadableValue != null,
    PendingSalePhase.none => false,
  };

  PendingSaleState copyWith({bool? busy}) {
    return PendingSaleState(
      phase: phase,
      pending: pending,
      unreadableValue: unreadableValue,
      busy: busy ?? this.busy,
      lookedUpNotFound: lookedUpNotFound,
      lookupFailed: lookupFailed,
    );
  }
}

/// Owns the sale submission lifecycle for the signed-in account and shop,
/// outside any screen: it survives leaving New Sale, and the saved request
/// survives restarts. One action at a time; extra taps are ignored.
class PendingSaleController extends AsyncNotifier<PendingSaleState> {
  PendingSaleScope? _scope;

  @override
  Future<PendingSaleState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    final shopId = ref.watch(
      shopAccessProvider.select((access) => access.value?.shopId),
    );
    final scope = userId == null || shopId == null
        ? null
        : PendingSaleScope(userId: userId, shopId: shopId);
    _scope = scope;
    if (scope == null) return const PendingSaleState.none();

    try {
      final pending = await ref.read(submitSaleProvider).loadPending(scope);
      return pending == null
          ? const PendingSaleState.none()
          : PendingSaleState(phase: PendingSalePhase.pending, pending: pending);
    } on PendingSaleStoreException catch (error) {
      return PendingSaleState(
        phase: PendingSalePhase.unreadable,
        unreadableValue: error.rawValue,
      );
    }
  }

  /// Submits a new sale. Null when nothing was done (no shop, still
  /// loading, or another action is running).
  Future<SaleOutcome?> submit(SaleDraft draft) async {
    final scope = _scope;
    final current = state.value;
    if (scope == null || current == null || current.busy) return null;
    if (current.blocksCheckout) return SaleOutcomeBlocked(current.pending);

    return _run(
      current,
      () => ref.read(submitSaleProvider).submit(draft, scope),
    );
  }

  /// Asks the database whether the unresolved sale was recorded.
  Future<SaleOutcome?> lookUp() async {
    final scope = _scope;
    final current = state.value;
    if (scope == null ||
        current == null ||
        current.busy ||
        current.phase != PendingSalePhase.pending) {
      return null;
    }
    return _run(
      current,
      () => ref.read(submitSaleProvider).lookUpPending(scope),
    );
  }

  /// Resends the unresolved sale unchanged, after the cashier confirmed the
  /// customer has paid and is waiting.
  Future<SaleOutcome?> retry({required bool customerConfirmedPaid}) async {
    final scope = _scope;
    final current = state.value;
    if (scope == null ||
        current == null ||
        current.busy ||
        current.phase != PendingSalePhase.pending ||
        !customerConfirmedPaid) {
      return null;
    }
    return _run(
      current,
      () => ref
          .read(submitSaleProvider)
          .retryPending(scope, customerConfirmedPaid: true),
    );
  }

  /// Sets the unresolved sale aside so a new sale can start. It is kept on
  /// the device and looked up again later, because the original request
  /// may still be recorded. Only allowed when [PendingSaleState.canAbandon].
  /// Returns whether it was set aside.
  Future<bool> abandon() async {
    final scope = _scope;
    final current = state.value;
    if (scope == null ||
        current == null ||
        current.busy ||
        !current.canAbandon) {
      return false;
    }

    state = AsyncData(current.copyWith(busy: true));
    try {
      final submitSale = ref.read(submitSaleProvider);
      final unreadable = current.unreadableValue;
      if (current.phase == PendingSalePhase.unreadable && unreadable != null) {
        await submitSale.abandonUnreadable(scope, unreadable);
      } else {
        await submitSale.abandonPending(scope);
      }
    } catch (_) {
      state = AsyncData(current.copyWith(busy: false));
      return false;
    }
    state = const AsyncData(PendingSaleState.none());
    return true;
  }

  /// Reads the saved sale again (after the device could not read it).
  void reload() => ref.invalidateSelf();

  Future<SaleOutcome?> _run(
    PendingSaleState current,
    Future<SaleOutcome?> Function() action,
  ) async {
    state = AsyncData(current.copyWith(busy: true));
    final SaleOutcome? outcome;
    try {
      outcome = await action();
    } catch (_) {
      // The saved request was not touched; show it again.
      state = AsyncData(current.copyWith(busy: false));
      rethrow;
    }
    state = AsyncData(_stateAfter(outcome, current));
    return outcome;
  }

  static PendingSaleState _stateAfter(
    SaleOutcome? outcome,
    PendingSaleState before,
  ) {
    PendingSaleState pending(
      PendingSaleRequest request, {
      bool? notFound,
      bool lookupFailed = false,
    }) => PendingSaleState(
      phase: PendingSalePhase.pending,
      pending: request,
      lookedUpNotFound: notFound ?? before.lookedUpNotFound,
      lookupFailed: lookupFailed,
    );

    final kept = before.pending;
    return switch (outcome) {
      // A refused retry: the first attempt may still arrive.
      SaleOutcomeRejected(requestKept: true) when kept != null => pending(kept),
      SaleOutcomeRecorded() ||
      SaleOutcomeRejected() => const PendingSaleState.none(),
      SaleOutcomeUnknown(:final pending) => PendingSaleState(
        phase: PendingSalePhase.pending,
        pending: pending,
      ),
      SaleOutcomeNotFound(pending: final request) => pending(
        request,
        notFound: true,
      ),
      SaleOutcomeLookupFailed(pending: final request) => pending(
        request,
        lookupFailed: true,
      ),
      SaleOutcomeBlocked() ||
      SaleOutcomeNotSaved() => before.copyWith(busy: false),
      // Nothing was saved any more: it had already been resolved.
      null => const PendingSaleState.none(),
    };
  }
}

final pendingSaleControllerProvider =
    AsyncNotifierProvider<PendingSaleController, PendingSaleState>(
      PendingSaleController.new,
    );

/// Sales set aside on this device that were recorded after all. Looked up
/// (never resent) each time New Sale opens; each stays until the cashier
/// acknowledges it.
class AbandonedSalesController
    extends AsyncNotifier<List<AbandonedSaleRecorded>> {
  PendingSaleScope? _scope;

  @override
  Future<List<AbandonedSaleRecorded>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    final shopId = ref.watch(
      shopAccessProvider.select((access) => access.value?.shopId),
    );
    final scope = userId == null || shopId == null
        ? null
        : PendingSaleScope(userId: userId, shopId: shopId);
    _scope = scope;
    if (scope == null) return const [];
    return ref.read(submitSaleProvider).reconcileAbandoned(scope);
  }

  /// The cashier has seen it. Returns whether it was removed.
  Future<bool> acknowledge(String idempotencyKey) async {
    final scope = _scope;
    final current = state.value;
    if (scope == null || current == null) return false;
    try {
      await ref
          .read(submitSaleProvider)
          .acknowledgeAbandoned(scope, idempotencyKey);
    } catch (_) {
      return false;
    }
    state = AsyncData([
      for (final item in current)
        if (item.abandoned.request.idempotencyKey != idempotencyKey) item,
    ]);
    return true;
  }
}

final abandonedSalesProvider =
    AsyncNotifierProvider.autoDispose<
      AbandonedSalesController,
      List<AbandonedSaleRecorded>
    >(AbandonedSalesController.new);
