import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/suppliers/domain/entities/supplier.dart';
import 'package:shopmate/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:shopmate/features/suppliers/presentation/providers/supplier_providers.dart';

Supplier _supplier(String id, String name) {
  return Supplier(
    id: id,
    shopId: 'shop-1',
    name: name,
    isActive: true,
    createdAt: DateTime.utc(2026, 10, 6),
    updatedAt: DateTime.utc(2026, 10, 6),
  );
}

class _FakeRepository implements SupplierRepository {
  int listReads = 0;
  bool? lastIncludeInactive;
  List<Supplier> suppliers = [_supplier('s-1', 'Kofi Bentley')];

  @override
  Future<List<Supplier>> getSuppliers({bool includeInactive = false}) async {
    listReads++;
    lastIncludeInactive = includeInactive;
    return suppliers;
  }

  @override
  Future<Supplier> getSupplierById(String id) async => _supplier(id, 'Tuth');

  @override
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async => _supplier('new', name);

  @override
  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    required bool isActive,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async => _supplier(id, name);
}

void main() {
  late _FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeRepository();
    container = ProviderContainer(
      overrides: [supplierRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  test('suppliersProvider loads active suppliers via the use case', () async {
    final subscription = container.listen(suppliersProvider, (_, _) {});
    addTearDown(subscription.close);

    final suppliers = await container.read(suppliersProvider.future);

    expect(suppliers.single.name, 'Kofi Bentley');
    expect(repository.lastIncludeInactive, isFalse);
  });

  test('suppliersProvider re-reads after it is disposed', () async {
    final first = container.listen(suppliersProvider, (_, _) {});
    await container.read(suppliersProvider.future);
    first.close();
    await container.pump();

    repository.suppliers = [
      _supplier('s-1', 'Kofi Bentley'),
      _supplier('s-2', 'Tuth'),
    ];

    final second = container.listen(suppliersProvider, (_, _) {});
    addTearDown(second.close);
    final suppliers = await container.read(suppliersProvider.future);

    expect(suppliers, hasLength(2));
    expect(repository.listReads, 2);
  });

  test('supplierProvider loads one supplier by id', () async {
    final provider = supplierProvider('s-9');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final supplier = await container.read(provider.future);

    expect(supplier.id, 's-9');
  });

  test('write use cases are wired to the repository', () async {
    final created = await container
        .read(createSupplierProvider)
        .call(name: 'New Supplier');
    final updated = await container
        .read(updateSupplierProvider)
        .call(id: 's-1', name: 'Renamed', isActive: true);

    expect(created.name, 'New Supplier');
    expect(updated.name, 'Renamed');
  });
}
