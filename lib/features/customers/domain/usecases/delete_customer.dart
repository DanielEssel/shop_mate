import '../repositories/customer_repository.dart';

class DeleteCustomer {
  DeleteCustomer(this._repository);

  final CustomerRepository _repository;

  Future<void> call(String id) {
    return _repository.deleteCustomer(id);
  }
}
