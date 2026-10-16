import '../entities/pending_sale_request.dart';
import '../entities/sale.dart';
import '../entities/sale_outcome.dart';
import '../entities/sale_payment_summary.dart';

abstract class SaleRepository {
  /// Sends [request] to the database: `create_sale_idempotent` for
  /// standard sales, `create_credit_sale_with_initial_payment` for credit,
  /// with the request's key and exact payload. Only product ids and
  /// quantities are sent; prices, discounts and totals are the database's.
  /// Failures throw `SaleRequestException`.
  Future<SaleSubmission> submitSale(PendingSaleRequest request);

  /// The sale recorded under [idempotencyKey] in the caller's shop, or null.
  /// Never creates anything. Failures throw `SaleRequestException`.
  Future<String?> findSaleByIdempotencyKey(String idempotencyKey);

  Future<List<Sale>> getSales();

  Future<Sale> getSaleById(String id);

  Future<SalePaymentSummary> getSalePaymentSummary(String saleId);
}
