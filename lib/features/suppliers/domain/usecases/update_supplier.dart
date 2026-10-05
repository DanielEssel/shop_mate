import '../entities/supplier.dart';
import '../repositories/supplier_repository.dart';

class UpdateSupplier {
  UpdateSupplier(this._repository);

  final SupplierRepository _repository;

  Future<Supplier> call({
    required String id,
    required String name,
    required bool isActive,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    return _repository.updateSupplier(
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
