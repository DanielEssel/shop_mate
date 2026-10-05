import '../entities/cart_item.dart';
import '../entities/sale.dart';
import '../entities/sale_payment_summary.dart';

abstract class SaleRepository {
  Future<Sale> createSale({
    String? customerId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
  });

  Future<Sale> createCreditSaleWithInitialPayment({
    required String customerId,
    required List<CartItem> items,
    required double initialPaymentAmount,
    required String? initialPaymentMethod,
    required String idempotencyKey,
  });

  Future<List<Sale>> getSales();

  Future<Sale> getSaleById(String id);

  Future<SalePaymentSummary> getSalePaymentSummary(String saleId);
}
