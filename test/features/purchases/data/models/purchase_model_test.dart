import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/purchases/data/models/purchase_model.dart';
import 'package:shopmate/features/purchases/domain/entities/purchase.dart';

const _supplierId = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> _row() {
  return {
    'id': '22222222-2222-4222-8222-222222222222',
    'shop_id': '33333333-3333-4333-8333-333333333333',
    'purchase_number': 'PU-20261006090000-ABC123',
    'supplier_id': _supplierId,
    'supplier_name': 'Kofi Bentley',
    'supplier_phone': '0240000001',
    'total_amount': 60,
    'amount_paid': 25.5,
    'balance': 34.5,
    'payment_method': 'credit',
    'status': 'completed',
    'purchase_date': '2026-10-06',
    'notes': 'Delivered',
    'created_by': '44444444-4444-4444-8444-444444444444',
    'created_at': '2026-10-06T09:00:00+00:00',
    'updated_at': '2026-10-06T09:05:00+00:00',
  };
}

PurchaseModel _parse(Map<String, Object?> row) {
  return PurchaseModel.fromJson(Map<String, Object?>.from(row));
}

void main() {
  test('parses a linked supplier id', () {
    final purchase = _parse(_row());

    expect(purchase.supplierId, _supplierId);
  });

  test('null supplier_id means no linked supplier', () {
    final purchase = _parse({..._row(), 'supplier_id': null});

    expect(purchase.supplierId, isNull);
  });

  test('missing supplier_id means no linked supplier', () {
    final purchase = _parse(_row()..remove('supplier_id'));

    expect(purchase.supplierId, isNull);
  });

  for (final malformed in <Object>[
    42,
    true,
    <String>['id'],
    <String, String>{},
  ]) {
    test('rejects a malformed supplier_id (${malformed.runtimeType})', () {
      expect(
        () => _parse({..._row(), 'supplier_id': malformed}),
        throwsFormatException,
      );
    });
  }

  test('existing purchase fields still parse unchanged', () {
    final Purchase purchase = _parse(_row());

    expect(purchase.id, '22222222-2222-4222-8222-222222222222');
    expect(purchase.purchaseNumber, 'PU-20261006090000-ABC123');
    expect(purchase.supplierName, 'Kofi Bentley');
    expect(purchase.supplierPhone, '0240000001');
    expect(purchase.totalAmount, 60);
    expect(purchase.amountPaid, 25.5);
    expect(purchase.balance, 34.5);
    expect(purchase.paymentMethod, 'credit');
    expect(purchase.status, 'completed');
    expect(purchase.purchaseDate, DateTime(2026, 10, 6));
    expect(purchase.notes, 'Delivered');
    expect(purchase.createdBy, '44444444-4444-4444-8444-444444444444');
    expect(purchase.createdAt, DateTime.utc(2026, 10, 6, 9));
    expect(purchase.updatedAt, DateTime.utc(2026, 10, 6, 9, 5));
    expect(purchase.hasBalance, isTrue);
  });

  test('an unlinked historical purchase keeps its snapshot', () {
    final purchase = _parse({
      ..._row(),
      'supplier_id': null,
      'supplier_name': 'Tuth',
      'supplier_phone': null,
    });

    expect(purchase.supplierId, isNull);
    expect(purchase.supplierName, 'Tuth');
    expect(purchase.supplierPhone, isNull);
  });

  test('toJson round-trips supplier_id', () {
    expect(_parse(_row()).toJson()['supplier_id'], _supplierId);
    expect(
      _parse({..._row(), 'supplier_id': null}).toJson()['supplier_id'],
      isNull,
    );
  });
}
