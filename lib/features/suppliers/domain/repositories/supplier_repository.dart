import '../entities/supplier.dart';

abstract class SupplierRepository {
  /// Suppliers of the caller's shop, ordered by name. Only active suppliers
  /// unless [includeInactive] is true.
  Future<List<Supplier>> getSuppliers({bool includeInactive = false});

  Future<Supplier> getSupplierById(String id);

  /// Creates an active supplier and returns it as stored.
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  });

  /// Replaces the editable fields of supplier [id] and returns it as stored.
  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    required bool isActive,
    String? phone,
    String? email,
    String? address,
    String? notes,
  });
}
