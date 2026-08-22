import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class GetSale {
  const GetSale(this._repository);

  final SaleRepository _repository;

  Future<Sale> call(String id) {
    return _repository.getSaleById(id);
  }
}
