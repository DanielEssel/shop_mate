import '../entities/customer_credit_statement.dart';
import '../entities/customer_payment_request.dart';
import '../entities/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getCustomers();

  Future<Customer> getCustomerById(String id);

  Future<CustomerCreditStatement> getCustomerCreditStatement(String customerId);

  Future<void> recordCustomerPayment(RecordCustomerPaymentRequest request);

  Future<Customer> createCustomer(Customer customer);

  Future<Customer> updateCustomer(Customer customer);

  Future<void> deleteCustomer(String id);
}
