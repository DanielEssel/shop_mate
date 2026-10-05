import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/customers/data/models/customer_credit_statement_model.dart';
import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/domain/entities/customer_credit_statement.dart';
import 'package:shopmate/features/customers/domain/entities/customer_payment_request.dart';
import 'package:shopmate/features/customers/domain/repositories/customer_repository.dart';
import 'package:shopmate/features/customers/domain/usecases/get_customer_credit_statement.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';

class _LedgerRepository implements CustomerRepository {
  int statementReads = 0;
  List<Map<String, Object?>> creditSales = [];

  @override
  Future<CustomerCreditStatement> getCustomerCreditStatement(
    String customerId,
  ) async {
    statementReads++;
    return CustomerCreditStatementModel.fromRows(
      creditSales: creditSales,
      payments: const [],
    );
  }

  @override
  Future<List<Customer>> getCustomers() => throw UnimplementedError();

  @override
  Future<Customer> getCustomerById(String id) => throw UnimplementedError();

  @override
  Future<void> recordCustomerPayment(RecordCustomerPaymentRequest request) =>
      throw UnimplementedError();

  @override
  Future<Customer> createCustomer(Customer customer) =>
      throw UnimplementedError();

  @override
  Future<Customer> updateCustomer(Customer customer) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCustomer(String id) => throw UnimplementedError();
}

void main() {
  test(
    'statement is re-read after a credit sale once the screen is reopened',
    () async {
      final repository = _LedgerRepository();
      final container = ProviderContainer(
        overrides: [
          getCustomerCreditStatementProvider.overrideWithValue(
            GetCustomerCreditStatement(repository),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = customerCreditStatementProvider('customer-1');

      // First visit: no credit sales yet.
      final firstVisit = container.listen(provider, (_, _) {});
      final before = await container.read(provider.future);
      expect(before.outstandingBalance, 0);
      firstVisit.close();
      await container.pump();

      // A credit sale is recorded elsewhere in the app.
      repository.creditSales = [
        {
          'id': 'sale-1',
          'sale_number': 'SALE-0001',
          'total_amount': 120,
          'created_at': '2026-10-05T09:00:00Z',
          'customer_payment_allocations': <Map<String, Object?>>[],
        },
      ];

      // Second visit must reflect the ledger, not the cached statement.
      final secondVisit = container.listen(provider, (_, _) {});
      addTearDown(secondVisit.close);
      final after = await container.read(provider.future);

      expect(repository.statementReads, 2);
      expect(after.outstandingBalance, 120);
      expect(after.outstandingSales, hasLength(1));
    },
  );
}
