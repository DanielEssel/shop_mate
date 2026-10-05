import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/purchases/domain/entities/purchase.dart';
import 'package:shopmate/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:shopmate/features/purchases/domain/usecases/create_purchase.dart';

final _purchase = Purchase(
  id: 'purchase-1',
  purchaseNumber: 'PU-1',
  totalAmount: 10,
  amountPaid: 10,
  balance: 0,
  paymentMethod: 'cash',
  status: 'completed',
  purchaseDate: DateTime(2026, 10, 6),
  createdAt: DateTime.utc(2026, 10, 6),
  updatedAt: DateTime.utc(2026, 10, 6),
);

/// Records the supplierId each createPurchase call receives.
class _RecordingRepository implements PurchaseRepository {
  final supplierIds = <String?>[];

  @override
  Future<Purchase> createPurchase({
    String? supplierName,
    String? supplierPhone,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
    required DateTime purchaseDate,
    String? notes,
    String? supplierId,
  }) async {
    supplierIds.add(supplierId);
    return _purchase;
  }

  @override
  Future<List<Purchase>> getPurchases() => throw UnimplementedError();

  @override
  Future<Purchase> getPurchaseById(String id) => throw UnimplementedError();
}

Future<Purchase> _call(CreatePurchase useCase, {String? supplierId}) {
  return useCase.call(
    paymentMethod: 'cash',
    amountPaid: 10,
    purchaseDate: DateTime(2026, 10, 6),
    items: const [],
    supplierId: supplierId,
  );
}

void main() {
  test('passes supplierId through to the repository', () async {
    final repository = _RecordingRepository();

    final result = await _call(
      CreatePurchase(repository),
      supplierId: 'supplier-1',
    );

    expect(result, same(_purchase));
    expect(repository.supplierIds, ['supplier-1']);
  });

  test('existing callers that omit supplierId pass null', () async {
    final repository = _RecordingRepository();

    await CreatePurchase(repository).call(
      paymentMethod: 'cash',
      amountPaid: 10,
      purchaseDate: DateTime(2026, 10, 6),
      items: const [],
    );

    expect(repository.supplierIds, [null]);
  });
}
