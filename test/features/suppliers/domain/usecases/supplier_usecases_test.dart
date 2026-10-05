import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/suppliers/domain/entities/supplier.dart';
import 'package:shopmate/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:shopmate/features/suppliers/domain/usecases/create_supplier.dart';
import 'package:shopmate/features/suppliers/domain/usecases/get_supplier.dart';
import 'package:shopmate/features/suppliers/domain/usecases/get_suppliers.dart';
import 'package:shopmate/features/suppliers/domain/usecases/update_supplier.dart';

final _supplier = Supplier(
  id: 'supplier-1',
  shopId: 'shop-1',
  name: 'Kofi Bentley',
  isActive: true,
  createdAt: DateTime.utc(2026, 10, 6),
  updatedAt: DateTime.utc(2026, 10, 6),
);

/// Records each call so the tests can check exactly what was delegated.
class _RecordingRepository implements SupplierRepository {
  final calls = <String>[];

  @override
  Future<List<Supplier>> getSuppliers({bool includeInactive = false}) async {
    calls.add('getSuppliers(includeInactive: $includeInactive)');
    return [_supplier];
  }

  @override
  Future<Supplier> getSupplierById(String id) async {
    calls.add('getSupplierById($id)');
    return _supplier;
  }

  @override
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    calls.add('createSupplier($name, $phone, $email, $address, $notes)');
    return _supplier;
  }

  @override
  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    required bool isActive,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    calls.add(
      'updateSupplier($id, $name, $isActive, $phone, $email, $address, $notes)',
    );
    return _supplier;
  }
}

void main() {
  late _RecordingRepository repository;

  setUp(() => repository = _RecordingRepository());

  test('GetSuppliers delegates with active-only by default', () async {
    final result = await GetSuppliers(repository).call();

    expect(result, [_supplier]);
    expect(repository.calls, ['getSuppliers(includeInactive: false)']);
  });

  test('GetSuppliers passes includeInactive through', () async {
    await GetSuppliers(repository).call(includeInactive: true);

    expect(repository.calls, ['getSuppliers(includeInactive: true)']);
  });

  test('GetSupplier delegates the id', () async {
    final result = await GetSupplier(repository).call('supplier-1');

    expect(result, same(_supplier));
    expect(repository.calls, ['getSupplierById(supplier-1)']);
  });

  test('CreateSupplier delegates every field unchanged', () async {
    final result = await CreateSupplier(repository).call(
      name: 'Kofi Bentley',
      phone: '0240000001',
      email: 'kofi@example.com',
      address: 'Kumasi',
      notes: 'Mondays',
    );

    expect(result, same(_supplier));
    expect(repository.calls, [
      'createSupplier(Kofi Bentley, 0240000001, kofi@example.com, Kumasi, Mondays)',
    ]);
  });

  test('UpdateSupplier delegates every field unchanged', () async {
    final result = await UpdateSupplier(repository).call(
      id: 'supplier-1',
      name: 'Kofi Bentley Ltd',
      isActive: false,
      phone: null,
      email: 'kofi@example.com',
    );

    expect(result, same(_supplier));
    expect(repository.calls, [
      'updateSupplier(supplier-1, Kofi Bentley Ltd, false, null, '
          'kofi@example.com, null, null)',
    ]);
  });
}
