import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class UpdateCustomer {
  UpdateCustomer(this._repository);

  final CustomerRepository _repository;

  Future<Customer> call(Customer customer) {
    return _repository.updateCustomer(customer);
  }
}
