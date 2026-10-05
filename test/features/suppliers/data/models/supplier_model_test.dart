import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/suppliers/data/models/supplier_model.dart';
import 'package:shopmate/features/suppliers/domain/entities/supplier.dart';

Map<String, Object?> _fullRow() {
  return {
    'id': '11111111-1111-4111-8111-111111111111',
    'shop_id': '22222222-2222-4222-8222-222222222222',
    'name': 'Kofi Bentley',
    'phone': '0240000001',
    'email': 'kofi@example.com',
    'address': 'Kumasi Central Market',
    'notes': 'Delivers on Mondays',
    'is_active': true,
    'created_by': '33333333-3333-4333-8333-333333333333',
    'created_at': '2026-10-06T09:15:30.123456+00:00',
    'updated_at': '2026-10-06T10:00:00+00:00',
  };
}

void main() {
  test('parses a full row', () {
    final supplier = SupplierModel.fromRow(_fullRow());

    expect(supplier.id, '11111111-1111-4111-8111-111111111111');
    expect(supplier.shopId, '22222222-2222-4222-8222-222222222222');
    expect(supplier.name, 'Kofi Bentley');
    expect(supplier.phone, '0240000001');
    expect(supplier.email, 'kofi@example.com');
    expect(supplier.address, 'Kumasi Central Market');
    expect(supplier.notes, 'Delivers on Mondays');
    expect(supplier.isActive, isTrue);
    expect(supplier.createdBy, '33333333-3333-4333-8333-333333333333');
    expect(supplier.createdAt, DateTime.utc(2026, 10, 6, 9, 15, 30, 123, 456));
    expect(supplier.updatedAt, DateTime.utc(2026, 10, 6, 10));
  });

  test('is usable as the domain entity', () {
    final Supplier supplier = SupplierModel.fromRow(_fullRow());

    expect(supplier, isA<Supplier>());
    expect(supplier.name, 'Kofi Bentley');
  });

  test('parses null optional fields as null', () {
    final supplier = SupplierModel.fromRow({
      ..._fullRow(),
      'phone': null,
      'email': null,
      'address': null,
      'notes': null,
      'created_by': null,
      'is_active': false,
    });

    expect(supplier.phone, isNull);
    expect(supplier.email, isNull);
    expect(supplier.address, isNull);
    expect(supplier.notes, isNull);
    expect(supplier.createdBy, isNull);
    expect(supplier.isActive, isFalse);
  });

  test('treats missing optional fields as null', () {
    final row = _fullRow()
      ..remove('phone')
      ..remove('email')
      ..remove('address')
      ..remove('notes')
      ..remove('created_by');

    final supplier = SupplierModel.fromRow(row);

    expect(supplier.phone, isNull);
    expect(supplier.createdBy, isNull);
  });

  test('keeps the stored name exactly as returned', () {
    final supplier = SupplierModel.fromRow({
      ..._fullRow(),
      'name': 'ABC  Distributors Ltd',
    });

    expect(supplier.name, 'ABC  Distributors Ltd');
  });

  const requiredFields = [
    'id',
    'shop_id',
    'name',
    'is_active',
    'created_at',
    'updated_at',
  ];

  for (final field in requiredFields) {
    test('rejects a missing $field', () {
      final row = _fullRow()..remove(field);

      expect(() => SupplierModel.fromRow(row), throwsFormatException);
    });

    test('rejects a null $field', () {
      final row = _fullRow()..[field] = null;

      expect(() => SupplierModel.fromRow(row), throwsFormatException);
    });
  }

  final malformed = <String, Object>{
    'id': 42,
    'shop_id': false,
    'name': 7,
    'is_active': 'true',
    'created_at': 'yesterday',
    'updated_at': 1728200000,
    'phone': 240000001,
    'email': true,
    'address': 12,
    'notes': <String>['note'],
    'created_by': 99,
  };

  malformed.forEach((field, value) {
    test('rejects a malformed $field', () {
      final row = _fullRow()..[field] = value;

      expect(() => SupplierModel.fromRow(row), throwsFormatException);
    });
  });

  test('select columns cover every parsed field', () {
    for (final field in _fullRow().keys) {
      expect(SupplierModel.selectColumns, contains(field));
    }
  });
}
