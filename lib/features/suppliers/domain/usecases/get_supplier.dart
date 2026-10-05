import '../entities/supplier.dart';
import '../repositories/supplier_repository.dart';

class GetSupplier {
  GetSupplier(this._repository);

  final SupplierRepository _repository;

  Future<Supplier> call(String id) {
    return _repository.getSupplierById(id);
  }
}
