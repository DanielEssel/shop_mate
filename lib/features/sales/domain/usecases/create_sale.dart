import '../entities/cart_item.dart';
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

  Future<Sale> createCreditSaleWithInitialPayment({
    required String customerId,
    required List<CartItem> items,
    required double initialPaymentAmount,
    required String? initialPaymentMethod,
    required String idempotencyKey,
  }) {
    return _repository.createCreditSaleWithInitialPayment(
      customerId: customerId,
      items: items,
      initialPaymentAmount: initialPaymentAmount,
      initialPaymentMethod: initialPaymentMethod,
      idempotencyKey: idempotencyKey,
    );
  }
}
