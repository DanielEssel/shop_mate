import '../entities/purchase.dart';

abstract class PurchaseRepository {
  Future<Purchase> createPurchase({
    String? supplierName,
    String? supplierPhone,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
    required DateTime purchaseDate,
    String? notes,

    /// Optional linked supplier; null records the purchase without one.
    String? supplierId,
  });

  Future<List<Purchase>> getPurchases();

  Future<Purchase> getPurchaseById(String id);
}
