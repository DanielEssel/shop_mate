import '../entities/supplier.dart';
import '../repositories/supplier_repository.dart';

class GetSuppliers {
  GetSuppliers(this._repository);

  final SupplierRepository _repository;

  Future<List<Supplier>> call({bool includeInactive = false}) {
    return _repository.getSuppliers(includeInactive: includeInactive);
  }
}
