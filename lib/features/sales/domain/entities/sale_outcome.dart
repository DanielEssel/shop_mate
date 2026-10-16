import 'package:flutter/foundation.dart';

import 'pending_sale_request.dart';
import 'recorded_sale.dart';
import 'sale_request_exception.dart';

/// What the database returned for a request: the sale and whether it was
/// recorded earlier (null when the function cannot say, e.g. credit).
@immutable
class SaleSubmission {
  const SaleSubmission({required this.saleId, this.replayed});

  final String saleId;
  final bool? replayed;
}

/// The result of submitting, retrying or recovering a sale.
sealed class SaleOutcome {
  const SaleOutcome();
}

/// The sale is recorded; its saved request has been cleared.
final class SaleOutcomeRecorded extends SaleOutcome {
  const SaleOutcomeRecorded(
    this.recorded, {
    required this.replayed,
    this.fromRecovery = false,
  });

  final RecordedSale recorded;

  /// True when this request had been recorded before (so no new payment is
  /// due); null when unknown.
  final bool? replayed;

  /// Resolved from a saved request (lookup or retry), not a fresh sale.
  final bool fromRecovery;

  /// It had been recorded before this request (a replay or a lookup), so
  /// no payment is due.
  bool get alreadyRecorded => replayed == true;
}

/// The database refused this attempt: it recorded nothing.
///
/// On a first attempt (the only request sent) that settles it, and the
/// saved request has been cleared. On a retry it does not: the earlier
/// attempt, whose answer was lost, may still reach the database. The saved
/// request is then kept ([requestKept]).
final class SaleOutcomeRejected extends SaleOutcome {
  const SaleOutcomeRejected(this.error, {this.requestKept = false});

  final SaleRequestException error;
  final bool requestKept;
}

/// No answer: the sale may or may not be recorded. The saved request is
/// kept, and only the same key and payload may be sent again.
final class SaleOutcomeUnknown extends SaleOutcome {
  const SaleOutcomeUnknown(this.pending);

  final PendingSaleRequest pending;
}

/// The recovery lookup found no sale for the saved request (which may still
/// be on its way); the saved request is kept.
final class SaleOutcomeNotFound extends SaleOutcome {
  const SaleOutcomeNotFound(this.pending);

  final PendingSaleRequest pending;
}

/// The recovery lookup itself failed; the saved request is kept.
final class SaleOutcomeLookupFailed extends SaleOutcome {
  const SaleOutcomeLookupFailed(this.pending);

  final PendingSaleRequest pending;
}

/// Another sale is still unresolved on this device (or its saved record
/// cannot be read); nothing was sent.
final class SaleOutcomeBlocked extends SaleOutcome {
  const SaleOutcomeBlocked(this.pending);

  /// Null when the saved record is unreadable.
  final PendingSaleRequest? pending;
}

/// The request could not be saved on the device first; nothing was sent.
final class SaleOutcomeNotSaved extends SaleOutcome {
  const SaleOutcomeNotSaved(this.error);

  final PendingSaleStoreException error;
}

/// A request the cashier set aside that was recorded after all. It stays
/// on the device until the cashier has seen this.
@immutable
class AbandonedSaleRecorded {
  const AbandonedSaleRecorded(this.abandoned, this.recorded);

  final AbandonedSaleRequest abandoned;
  final RecordedSale recorded;
}
