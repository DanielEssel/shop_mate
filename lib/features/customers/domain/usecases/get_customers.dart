import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

class GetCustomers {
  GetCustomers(this._repository);

  final CustomerRepository _repository;

  Future<List<Customer>> call() {
    return _repository.getCustomers();
  }
}
