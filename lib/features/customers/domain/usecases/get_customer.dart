import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class GetCustomer {
  GetCustomer(this._repository);

  final CustomerRepository _repository;

  Future<Customer> call(String id) {
    return _repository.getCustomerById(id);
  }
}
