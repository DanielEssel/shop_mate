import 'dart:async';
import 'dart:convert';

import 'package:shopmate/features/sales/domain/entities/pending_sale_request.dart';
import 'package:shopmate/features/sales/domain/entities/sale.dart';
import 'package:shopmate/features/sales/domain/entities/sale_outcome.dart';
import 'package:shopmate/features/sales/domain/entities/sale_payment_summary.dart';
import 'package:shopmate/features/sales/domain/entities/sale_request_exception.dart';
import 'package:shopmate/features/sales/domain/repositories/pending_sale_store.dart';
import 'package:shopmate/features/sales/domain/repositories/sales_repository.dart';

/// Behaves like the database contract: a key that was recorded is replayed
/// (standard sales report replayed = true; credit cannot say), and a lookup
/// finds sales by key. Records every call, in order, into [events].
class FakeSaleRepository implements SaleRepository {
  FakeSaleRepository({List<String>? events}) : events = events ?? <String>[];

  final List<String> events;
  final submissions = <PendingSaleRequest>[];
  final lookups = <String>[];

  /// Sales recorded so far, by request key.
  final recordedByKey = <String, String>{};
  final _requests = <String, PendingSaleRequest>{};

  /// Thrown by the next submission, once (nothing recorded).
  Object? nextError;

  /// The next submission records the sale, then its answer is lost.
  bool nextAnswerLost = false;

  /// Thrown by the next lookup, once.
  Object? nextLookupError;

  /// The recorded row cannot be read back.
  bool readBackFails = false;

  /// While set, submissions wait for it.
  Completer<void>? submitGate;

  /// Called inside [submitSale], before anything happens (e.g. to check
  /// what was saved on the device at that moment).
  void Function(PendingSaleRequest request)? onSubmit;

  /// The recorded total for a request (default: the checkout's estimate).
  double Function(PendingSaleRequest request)? totalFor;
  double recordedDiscount = 0;

  /// The database already holds a sale for [request] (e.g. recorded before
  /// the app was restarted). Returns its id.
  String seedRecorded(PendingSaleRequest request) {
    final saleId = 'sale-${recordedByKey.length + 1}';
    recordedByKey[request.idempotencyKey] = saleId;
    _requests[saleId] = request;
    return saleId;
  }

  @override
  Future<SaleSubmission> submitSale(PendingSaleRequest request) async {
    events.add('rpc:${request.idempotencyKey}');
    submissions.add(request);
    onSubmit?.call(request);
    await submitGate?.future;

    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }

    final isCredit = request.draft.kind == SaleRequestKind.credit;
    final existing = recordedByKey[request.idempotencyKey];
    if (existing != null) {
      final original = _requests[existing]!;
      if (!original.draft.sameRequestAs(request.draft)) {
        throw SaleRequestException(
          isCredit
              ? SaleRequestErrorKind.creditKeyConflict
              : SaleRequestErrorKind.keyConflict,
          code: isCredit ? 'P0001' : 'SMI01',
        );
      }
      return SaleSubmission(saleId: existing, replayed: isCredit ? null : true);
    }

    final saleId = 'sale-${recordedByKey.length + 1}';
    recordedByKey[request.idempotencyKey] = saleId;
    _requests[saleId] = request;

    if (nextAnswerLost) {
      nextAnswerLost = false;
      throw const SaleRequestException(SaleRequestErrorKind.outcomeUnknown);
    }
    return SaleSubmission(saleId: saleId, replayed: isCredit ? null : false);
  }

  @override
  Future<String?> findSaleByIdempotencyKey(String idempotencyKey) async {
    events.add('lookup:$idempotencyKey');
    lookups.add(idempotencyKey);
    final error = nextLookupError;
    if (error != null) {
      nextLookupError = null;
      throw error;
    }
    return recordedByKey[idempotencyKey];
  }

  @override
  Future<Sale> getSaleById(String id) async {
    events.add('read:$id');
    if (readBackFails) throw Exception('read-back failed');
    final request = _requests[id]!;
    final draft = request.draft;
    final total = totalFor?.call(request) ?? draft.estimatedTotal;
    final isCredit = draft.kind == SaleRequestKind.credit;
    return Sale(
      id: id,
      saleNumber: 'SL-${id.toUpperCase()}',
      totalAmount: total,
      discountAmount: recordedDiscount,
      paymentMethod: draft.paymentMethod,
      amountPaid: draft.amountPaid,
      changeAmount: isCredit || draft.amountPaid <= total
          ? 0
          : draft.amountPaid - total,
      customerId: draft.customerId,
      createdAt: DateTime(2026, 10, 15, 10),
    );
  }

  @override
  Future<List<Sale>> getSales() async => const [];

  @override
  Future<SalePaymentSummary> getSalePaymentSummary(String saleId) =>
      throw UnimplementedError();
}

/// The device store, in memory, with switchable failures. Stores the JSON
/// exactly as the real store would.
class InMemoryPendingSaleStore implements PendingSaleStore {
  InMemoryPendingSaleStore({List<String>? events})
    : events = events ?? <String>[];

  final List<String> events;
  final values = <PendingSaleScope, String>{};

  bool failSave = false;
  bool failDelete = false;
  bool failLoad = false;

  /// Abandoned requests, as the real store keeps them: one JSON string
  /// each (unreadable ones verbatim).
  final abandoned = <PendingSaleScope, List<String>>{};

  /// Writing to the abandoned requests fails.
  bool failAbandon = false;

  /// The abandoned requests' keys for [scope], readable ones only.
  List<String> abandonedKeys(PendingSaleScope scope) => [
    for (final request in _readableAbandoned(scope))
      request.request.idempotencyKey,
  ];

  /// Puts a raw (possibly unreadable) record in place, as a crash or an
  /// older build might have left it.
  void putRaw(PendingSaleScope scope, String raw) => values[scope] = raw;

  PendingSaleRequest? peek(PendingSaleScope scope) {
    final raw = values[scope];
    return raw == null
        ? null
        : PendingSaleRequest.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map),
          );
  }

  @override
  Future<PendingSaleRequest?> load(PendingSaleScope scope) async {
    if (failLoad) throw const PendingSaleStoreException('load');
    final raw = values[scope];
    if (raw == null) return null;
    try {
      return PendingSaleRequest.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } catch (error) {
      throw PendingSaleStoreException('load', rawValue: raw, cause: error);
    }
  }

  @override
  Future<void> save(PendingSaleRequest request) async {
    events.add('save:${request.idempotencyKey}');
    if (failSave) throw const PendingSaleStoreException('save');
    values[request.scope] = jsonEncode(request.toJson());
  }

  @override
  Future<void> delete(PendingSaleScope scope) async {
    events.add('delete');
    if (failDelete) throw const PendingSaleStoreException('delete');
    values.remove(scope);
  }

  @override
  Future<void> abandon(PendingSaleRequest request, DateTime abandonedAt) async {
    events.add('abandon:${request.idempotencyKey}');
    if (failAbandon) throw const PendingSaleStoreException('save');
    if (!abandonedKeys(request.scope).contains(request.idempotencyKey)) {
      (abandoned[request.scope] ??= []).add(
        jsonEncode(
          AbandonedSaleRequest(
            request: request,
            abandonedAt: abandonedAt,
          ).toJson(),
        ),
      );
    }
    await delete(request.scope);
  }

  @override
  Future<void> abandonUnreadable(
    PendingSaleScope scope,
    String rawValue,
  ) async {
    events.add('abandon:unreadable');
    if (failAbandon) throw const PendingSaleStoreException('save');
    final entries = abandoned[scope] ??= [];
    if (!entries.contains(rawValue)) entries.add(rawValue);
    await delete(scope);
  }

  @override
  Future<List<AbandonedSaleRequest>> loadAbandoned(
    PendingSaleScope scope,
  ) async => _readableAbandoned(scope);

  @override
  Future<void> removeAbandoned(
    PendingSaleScope scope,
    String idempotencyKey,
  ) async {
    events.add('removeAbandoned:$idempotencyKey');
    if (failAbandon) throw const PendingSaleStoreException('save');
    abandoned[scope]?.removeWhere(
      (entry) => _decode(entry)?.request.idempotencyKey == idempotencyKey,
    );
  }

  List<AbandonedSaleRequest> _readableAbandoned(PendingSaleScope scope) => [
    for (final entry in abandoned[scope] ?? const <String>[]) ?_decode(entry),
  ];

  static AbandonedSaleRequest? _decode(String entry) {
    try {
      return AbandonedSaleRequest.fromJson(
        Map<String, Object?>.from(jsonDecode(entry) as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
