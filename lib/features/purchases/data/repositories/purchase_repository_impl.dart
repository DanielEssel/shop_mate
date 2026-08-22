import '../../domain/entities/purchase.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../datasources/purchase_remote_datasource.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  PurchaseRepositoryImpl(this._remoteDataSource);

  final PurchaseRemoteDataSource _remoteDataSource;

  @override
  Future<Purchase> createPurchase({
    String? supplierName,
    String? supplierPhone,
    required String paymentMethod,
    required double amountPaid,
    required DateTime purchaseDate,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final purchaseId = await _remoteDataSource.createPurchase(
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      purchaseDate: purchaseDate,
      notes: notes,
      items: items,
    );

    return _remoteDataSource.getPurchaseById(purchaseId);
  }

  @override
  Future<List<Purchase>> getPurchases() {
    return _remoteDataSource.getPurchases();
  }

  @override
  Future<Purchase> getPurchaseById(String id) {
    return _remoteDataSource.getPurchaseById(id);
  }
}