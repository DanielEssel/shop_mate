import '../entities/customer_credit_statement.dart';
import '../repositories/customer_repository.dart';

class GetCustomerCreditStatement {
  GetCustomerCreditStatement(this._repository);

  final CustomerRepository _repository;

  Future<CustomerCreditStatement> call(String customerId) {
    return _repository.getCustomerCreditStatement(customerId);
  }
}
