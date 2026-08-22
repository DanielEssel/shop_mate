import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_remote_datasource.dart';

class SalesRepositoryImpl implements SaleRepository {
  SalesRepositoryImpl(this._remoteDataSource);

  final SalesRemoteDataSource _remoteDataSource;

  @override
  Future<Sale> createSale({
    String? customerId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amountPaid,
  }) async {
    final saleId = await _remoteDataSource.createSale(
      customerId: customerId,
      items: items,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
    );

    return _remoteDataSource.getSaleById(saleId);
  }

  @override
  Future<List<Sale>> getSales() {
    return _remoteDataSource.getSales();
  }

  @override
  Future<Sale> getSaleById(String id) {
    return _remoteDataSource.getSaleById(id);
  }
}