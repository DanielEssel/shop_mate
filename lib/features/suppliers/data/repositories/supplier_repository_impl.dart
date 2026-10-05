import '../../domain/entities/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../datasources/supplier_remote_datasource.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  SupplierRepositoryImpl(this._remoteDataSource);

  final SupplierRemoteDataSource _remoteDataSource;

  @override
  Future<List<Supplier>> getSuppliers({bool includeInactive = false}) {
    return _remoteDataSource.getSuppliers(includeInactive: includeInactive);
  }

  @override
  Future<Supplier> getSupplierById(String id) {
    return _remoteDataSource.getSupplierById(id);
  }

  @override
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    return _remoteDataSource.createSupplier(
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
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
  }) {
    return _remoteDataSource.updateSupplier(
      id: id,
      name: name,
      isActive: isActive,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
  }
}
