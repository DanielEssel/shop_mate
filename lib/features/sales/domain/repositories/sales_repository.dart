import '../entities/sale.dart';

abstract class SaleRepository {
  Future<Sale> createSale({
    String? customerId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
  });

  Future<List<Sale>> getSales();

  Future<Sale> getSaleById(String id);
}