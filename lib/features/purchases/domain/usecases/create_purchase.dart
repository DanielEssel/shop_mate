import '../entities/purchase.dart';
import '../repositories/purchase_repository.dart';

class CreatePurchase {
  const CreatePurchase(this._repository);

  final PurchaseRepository _repository;

  Future<Purchase> call({
    String? supplierName,
    String? supplierPhone,
    required String paymentMethod,
    required double amountPaid,
    required DateTime purchaseDate,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) {
    return _repository.createPurchase(
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      purchaseDate: purchaseDate,
      notes: notes,
      items: items,
    );
  }
}