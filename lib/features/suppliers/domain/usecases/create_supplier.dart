import '../entities/supplier.dart';
import '../repositories/supplier_repository.dart';

class CreateSupplier {
  CreateSupplier(this._repository);

  final SupplierRepository _repository;

  Future<Supplier> call({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    return _repository.createSupplier(
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
  }
}
