import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/sales/domain/entities/pending_sale_request.dart';
import 'package:shopmate/features/sales/domain/entities/sale_outcome.dart';
import 'package:shopmate/features/sales/domain/entities/sale_request_exception.dart';
import 'package:shopmate/features/sales/domain/usecases/submit_sale.dart';

import '../fake_sale_repository.dart';

const _scope = PendingSaleScope(userId: 'user-1', shopId: 'shop-1');
const _otherShop = PendingSaleScope(userId: 'user-1', shopId: 'shop-2');
const _otherUser = PendingSaleScope(userId: 'user-2', shopId: 'shop-1');

SaleDraft _cash({double paid = 20, List<SaleRequestItem>? items}) => SaleDraft(
  kind: SaleRequestKind.standard,
  paymentMethod: 'cash',
  amountPaid: paid,
  items:
      items ??
      const [
        SaleRequestItem(productId: 'rice', quantity: 2),
        SaleRequestItem(productId: 'oil', quantity: 1),
      ],
  estimatedTotal: 19.99,
);

const _credit = SaleDraft(
  kind: SaleRequestKind.credit,
  paymentMethod: 'credit',
  customerId: 'c-1',
  amountPaid: 5,
  initialPaymentMethod: 'mobile_money',
  items: [SaleRequestItem(productId: 'rice', quantity: 1)],
  estimatedTotal: 9,
);

void main() {
  late List<String> events;
  late FakeSaleRepository repository;
  late InMemoryPendingSaleStore store;
  late SubmitSale submitSale;
  var keys = 0;

  setUp(() {
    events = <String>[];
    repository = FakeSaleRepository(events: events);
    store = InMemoryPendingSaleStore(events: events);
    keys = 0;
    submitSale = SubmitSale(
      repository: repository,
      store: store,
      newKey: () => 'key-${++keys}',
      now: () => DateTime.utc(2026, 10, 15, 9, 30),
    );
  });

  group('PendingSaleRequest', () {
    test('round-trips through JSON exactly, items in order', () {
      final request = PendingSaleRequest(
        idempotencyKey: 'key-1',
        scope: _scope,
        draft: _credit,
        createdAt: DateTime.utc(2026, 10, 15, 9, 30),
      );
      final restored = PendingSaleRequest.fromJson(request.toJson());

      expect(restored.idempotencyKey, 'key-1');
      expect(restored.scope, _scope);
      expect(restored.draft.sameRequestAs(_credit), isTrue);
      expect(restored.draft.initialPaymentMethod, 'mobile_money');
      expect(restored.draft.estimatedTotal, 9);
      expect(restored.createdAt, DateTime.utc(2026, 10, 15, 9, 30));
      expect(request.toJson()['items'], [
        {'product_id': 'rice', 'quantity': 1},
      ]);
    });

    test('rejects incomplete or unknown records', () {
      final good = PendingSaleRequest(
        idempotencyKey: 'key-1',
        scope: _scope,
        draft: _cash(),
        createdAt: DateTime.utc(2026),
      ).toJson();
      for (final broken in <Map<String, Object?>>[
        {...good, 'version': 2},
        {...good, 'kind': 'barter'},
        {...good, 'idempotency_key': null},
        {...good, 'items': <Object?>[]},
        {
          ...good,
          'items': [
            {'product_id': 'rice', 'quantity': '2'},
          ],
        },
        {...good, 'created_at': 'yesterday'},
      ]) {
        expect(
          () => PendingSaleRequest.fromJson(broken),
          throwsFormatException,
        );
      }
    });

    test('the same request means same items in the same order', () {
      expect(_cash().sameRequestAs(_cash()), isTrue);
      expect(_cash().sameRequestAs(_cash(paid: 21)), isFalse);
      expect(
        _cash().sameRequestAs(
          _cash(
            items: const [
              SaleRequestItem(productId: 'oil', quantity: 1),
              SaleRequestItem(productId: 'rice', quantity: 2),
            ],
          ),
        ),
        isFalse,
      );
    });
  });

  group('submitting', () {
    test('the request is saved on the device before it is sent', () async {
      PendingSaleRequest? savedWhenSent;
      repository.onSubmit = (_) => savedWhenSent = store.peek(_scope);

      await submitSale.submit(_cash(), _scope);

      expect(events.take(2), ['save:key-1', 'rpc:key-1']);
      expect(savedWhenSent?.idempotencyKey, 'key-1');
    });

    test('if it cannot be saved, nothing is sent', () async {
      store.failSave = true;
      final outcome = await submitSale.submit(_cash(), _scope);

      expect(outcome, isA<SaleOutcomeNotSaved>());
      expect(repository.submissions, isEmpty);
    });

    test('recorded: cleared, read back, new sale', () async {
      final outcome = await submitSale.submit(_cash(), _scope);

      expect(outcome, isA<SaleOutcomeRecorded>());
      final recorded = outcome as SaleOutcomeRecorded;
      expect(recorded.replayed, isFalse);
      expect(recorded.alreadyRecorded, isFalse);
      expect(recorded.recorded.saleId, 'sale-1');
      expect(recorded.recorded.hasDetails, isTrue);
      expect(store.values, isEmpty);
    });

    test(
      'recorded but not readable: still recorded, cleared, no resend',
      () async {
        repository.readBackFails = true;
        final outcome = await submitSale.submit(_cash(), _scope);

        expect((outcome as SaleOutcomeRecorded).recorded.hasDetails, isFalse);
        expect(repository.submissions, hasLength(1));
        expect(store.values, isEmpty);
      },
    );

    for (final kind in [
      SaleRequestErrorKind.rejected,
      SaleRequestErrorKind.discountRefused,
      SaleRequestErrorKind.keyConflict,
      SaleRequestErrorKind.serviceUnavailable,
    ]) {
      test(
        'a definite refusal (${kind.name}) clears the saved request',
        () async {
          repository.nextError = SaleRequestException(kind, code: 'X');
          final outcome = await submitSale.submit(_cash(), _scope);

          expect((outcome as SaleOutcomeRejected).error.kind, kind);
          expect(outcome.requestKept, isFalse);
          expect(store.values, isEmpty);
          // The next sale gets a new key.
          await submitSale.submit(_cash(), _scope);
          expect(repository.submissions.last.idempotencyKey, 'key-2');
        },
      );
    }

    test('no answer: kept, and a new sale is blocked (nothing sent)', () async {
      repository.nextError = const SaleRequestException(
        SaleRequestErrorKind.outcomeUnknown,
      );
      final first = await submitSale.submit(_cash(), _scope);
      expect(first, isA<SaleOutcomeUnknown>());
      expect(store.peek(_scope)?.idempotencyKey, 'key-1');

      for (final draft in [_cash(), _cash(paid: 50)]) {
        final again = await submitSale.submit(draft, _scope);
        expect(again, isA<SaleOutcomeBlocked>());
      }
      expect(repository.submissions, hasLength(1));
    });

    test('an unexpected failure is treated as no answer', () async {
      repository.nextError = StateError('boom');
      expect(
        await submitSale.submit(_cash(), _scope),
        isA<SaleOutcomeUnknown>(),
      );
      expect(store.peek(_scope), isNotNull);
    });
  });

  group('recovery', () {
    setUp(() async {
      // The sale is recorded, but its answer never arrives.
      repository.nextAnswerLost = true;
      await submitSale.submit(_cash(), _scope);
      expect(store.peek(_scope), isNotNull);
    });

    test('lookup first: finds the recorded sale and clears it', () async {
      final outcome = await submitSale.lookUpPending(_scope);

      expect(outcome, isA<SaleOutcomeRecorded>());
      final recorded = outcome as SaleOutcomeRecorded;
      expect(recorded.recorded.saleId, 'sale-1');
      expect(recorded.alreadyRecorded, isTrue);
      expect(store.values, isEmpty);
      expect(repository.submissions, hasLength(1), reason: 'never resent');
    });

    test('a retry needs the cashier'
        's confirmation', () async {
      expect(
        () => submitSale.retryPending(_scope, customerConfirmedPaid: false),
        throwsArgumentError,
      );
      expect(repository.submissions, hasLength(1));
    });

    test('a confirmed retry sends the SAME key and payload, replaying the '
        'recorded sale', () async {
      final outcome = await submitSale.retryPending(
        _scope,
        customerConfirmedPaid: true,
      );

      final retried = repository.submissions.last;
      final original = repository.submissions.first;
      expect(retried.idempotencyKey, original.idempotencyKey);
      expect(retried.draft.sameRequestAs(original.draft), isTrue);
      expect((outcome as SaleOutcomeRecorded).replayed, isTrue);
      expect(outcome.recorded.saleId, 'sale-1');
      expect(repository.recordedByKey, hasLength(1));
      expect(store.values, isEmpty);
    });

    test('a failed lookup keeps the saved request', () async {
      repository.nextLookupError = Exception('offline');
      final outcome = await submitSale.lookUpPending(_scope);

      expect(outcome, isA<SaleOutcomeLookupFailed>());
      expect(store.peek(_scope), isNotNull);
    });

    test('saved requests belong to one account and shop', () async {
      expect(await submitSale.loadPending(_otherShop), isNull);
      expect(await submitSale.loadPending(_otherUser), isNull);
      expect(await submitSale.loadPending(_scope), isNotNull);
    });
  });

  group('not recorded yet', () {
    setUp(() async {
      repository.nextError = const SaleRequestException(
        SaleRequestErrorKind.outcomeUnknown,
      );
      await submitSale.submit(_cash(), _scope);
    });

    test('lookup finds nothing: kept, not resent', () async {
      final outcome = await submitSale.lookUpPending(_scope);

      expect(outcome, isA<SaleOutcomeNotFound>());
      expect(store.peek(_scope)?.idempotencyKey, 'key-1');
      expect(repository.submissions, hasLength(1));
    });

    test('a confirmed retry with the same key records it once', () async {
      final outcome = await submitSale.retryPending(
        _scope,
        customerConfirmedPaid: true,
      );

      expect(repository.submissions.last.idempotencyKey, 'key-1');
      expect((outcome as SaleOutcomeRecorded).replayed, isFalse);
      expect(outcome.fromRecovery, isTrue);
      // Recorded by this retry, not before it.
      expect(outcome.alreadyRecorded, isFalse);
      expect(store.values, isEmpty);
    });

    test('setting it aside keeps its key and payload, and frees checkout '
        'for a NEW key', () async {
      await submitSale.abandonPending(_scope);

      expect(store.values, isEmpty);
      final kept = (await store.loadAbandoned(_scope)).single;
      expect(kept.request.idempotencyKey, 'key-1');
      expect(kept.request.draft.sameRequestAs(_cash()), isTrue);
      expect(kept.abandonedAt, DateTime.utc(2026, 10, 15, 9, 30));
      expect(events, containsAllInOrder(['abandon:key-1', 'delete']));

      final next = await submitSale.submit(_cash(paid: 50), _scope);
      expect(next, isA<SaleOutcomeRecorded>());
      expect(
        repository.submissions.map((r) => r.idempotencyKey),
        ['key-1', 'key-2'],
        reason: 'the set-aside request is never resent',
      );
    });

    test('the cancellation race: the original request arrives after it was '
        'set aside, and is found, not lost', () async {
      expect(
        await submitSale.lookUpPending(_scope),
        isA<SaleOutcomeNotFound>(),
      );
      await submitSale.abandonPending(_scope);
      expect(await submitSale.reconcileAbandoned(_scope), isEmpty);

      // The delayed original reaches the database now.
      final original = repository.submissions.single;
      final saleId = repository.seedRecorded(original);

      final found = await submitSale.reconcileAbandoned(_scope);
      expect(found.single.recorded.saleId, saleId);
      expect(found.single.abandoned.request.idempotencyKey, 'key-1');
      expect(repository.submissions, hasLength(1), reason: 'lookups only');
      // Kept until the cashier has seen it.
      expect(store.abandonedKeys(_scope), ['key-1']);

      await submitSale.acknowledgeAbandoned(_scope, 'key-1');
      expect(store.abandonedKeys(_scope), isEmpty);
      expect(await submitSale.reconcileAbandoned(_scope), isEmpty);
    });

    test('a failed reconciliation lookup keeps it for next time', () async {
      await submitSale.abandonPending(_scope);
      repository
        ..seedRecorded(repository.submissions.single)
        ..nextLookupError = Exception('offline');

      expect(await submitSale.reconcileAbandoned(_scope), isEmpty);
      expect(store.abandonedKeys(_scope), ['key-1']);
      expect(await submitSale.reconcileAbandoned(_scope), hasLength(1));
    });

    test('if it cannot be set aside, it stays pending', () async {
      store.failAbandon = true;
      await expectLater(
        submitSale.abandonPending(_scope),
        throwsA(isA<PendingSaleStoreException>()),
      );
      expect(store.peek(_scope)?.idempotencyKey, 'key-1');
      expect(store.abandonedKeys(_scope), isEmpty);
    });

    test(
      'interrupted after keeping it: in both places, never neither',
      () async {
        store.failDelete = true;
        await expectLater(
          submitSale.abandonPending(_scope),
          throwsA(isA<PendingSaleStoreException>()),
        );
        expect(store.peek(_scope)?.idempotencyKey, 'key-1');
        expect(store.abandonedKeys(_scope), ['key-1']);

        // Setting it aside again does not duplicate it.
        store.failDelete = false;
        await submitSale.abandonPending(_scope);
        expect(store.abandonedKeys(_scope), ['key-1']);
        expect(store.values, isEmpty);
      },
    );

    for (final kind in [
      SaleRequestErrorKind.rejected,
      SaleRequestErrorKind.discountRefused,
      SaleRequestErrorKind.serviceUnavailable,
    ]) {
      test('a refused RETRY (${kind.name}) keeps the request: the first '
          'attempt may still arrive', () async {
        repository.nextError = SaleRequestException(kind, code: 'X');
        final outcome = await submitSale.retryPending(
          _scope,
          customerConfirmedPaid: true,
        );

        expect((outcome as SaleOutcomeRejected).requestKept, isTrue);
        expect(store.peek(_scope)?.idempotencyKey, 'key-1');
        expect(
          await submitSale.submit(_cash(), _scope),
          isA<SaleOutcomeBlocked>(),
          reason: 'no new key while it is unresolved',
        );
      });
    }
  });

  group('credit', () {
    test('the exact payload and key are saved, and reused on retry', () async {
      repository.nextError = const SaleRequestException(
        SaleRequestErrorKind.outcomeUnknown,
      );
      await submitSale.submit(_credit, _scope);
      final saved = store.peek(_scope)!;
      expect(saved.draft.sameRequestAs(_credit), isTrue);

      final outcome = await submitSale.retryPending(
        _scope,
        customerConfirmedPaid: true,
      );

      expect(repository.submissions.map((r) => r.idempotencyKey), [
        'key-1',
        'key-1',
      ]);
      expect(repository.submissions.last.draft.sameRequestAs(_credit), isTrue);
      // The credit function cannot say whether it replayed.
      expect((outcome as SaleOutcomeRecorded).replayed, isNull);
      expect(repository.recordedByKey, hasLength(1));
    });

    test('an answer lost after recording: the retry returns the same sale, '
        'so the initial payment is not recorded twice', () async {
      repository.nextAnswerLost = true;
      await submitSale.submit(_credit, _scope);
      final outcome = await submitSale.retryPending(
        _scope,
        customerConfirmedPaid: true,
      );

      expect((outcome as SaleOutcomeRecorded).recorded.saleId, 'sale-1');
      expect(repository.recordedByKey, hasLength(1));
    });
  });
}
