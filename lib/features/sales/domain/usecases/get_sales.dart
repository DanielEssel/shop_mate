import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class GetSales {
  const GetSales(this._repository);

  final SaleRepository _repository;

  Future<List<Sale>> call() {
    return _repository.getSales();
  }
}
