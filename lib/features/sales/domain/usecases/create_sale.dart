import '../entities/sale.dart';
import '../repositories/sales_repository.dart';

class CreateSale {
  CreateSale(this._repository);

  final SaleRepository _repository;

  Future<Sale> call({
    String? customerId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
  }) {
    return _repository.createSale(
      customerId: customerId,
      items: items,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
    );
  }
}