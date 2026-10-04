import '../entities/customer_payment_request.dart';
import '../repositories/customer_repository.dart';

class RecordCustomerPayment {
  RecordCustomerPayment(this._repository);

  final CustomerRepository _repository;

  Future<void> call(RecordCustomerPaymentRequest request) {
    return _repository.recordCustomerPayment(request);
  }
}
