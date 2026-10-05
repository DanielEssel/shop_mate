import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_payment_summary.dart';
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
  Future<Sale> createCreditSaleWithInitialPayment({
    required String customerId,
    required List<CartItem> items,
    required double initialPaymentAmount,
    required String? initialPaymentMethod,
    required String idempotencyKey,
  }) async {
    final saleId = await _remoteDataSource.createCreditSaleWithInitialPayment(
      customerId: customerId,
      items: items,
      initialPaymentAmount: initialPaymentAmount,
      initialPaymentMethod: initialPaymentMethod,
      idempotencyKey: idempotencyKey,
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

  @override
  Future<SalePaymentSummary> getSalePaymentSummary(String saleId) {
    return _remoteDataSource.getSalePaymentSummary(saleId);
  }
}
