import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_remote_datasource.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl(this._remoteDataSource);

  final CustomerRemoteDataSource _remoteDataSource;

  @override
  Future<List<Customer>> getCustomers() {
    return _remoteDataSource.getCustomers();
  }

  @override
  Future<Customer> getCustomerById(String id) {
    return _remoteDataSource.getCustomerById(id);
  }

  @override
  Future<Customer> createCustomer(Customer customer) {
    return _remoteDataSource.createCustomer({
      'name': customer.name,
      'phone': customer.phone,
      'email': customer.email,
      'address': customer.address,
      'notes': customer.notes,
      'is_active': customer.isActive,
    });
  }

  @override
  Future<Customer> updateCustomer(Customer customer) {
    return _remoteDataSource.updateCustomer(
      customer.id,
      {
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'notes': customer.notes,
        'is_active': customer.isActive,
      },
    );
  }

  @override
  Future<void> deleteCustomer(String id) {
    return _remoteDataSource.deleteCustomer(id);
  }
}