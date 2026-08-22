import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/customer_remote_datasource.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/create_customer.dart';
import '../../domain/usecases/delete_customer.dart';
import '../../domain/usecases/get_customer.dart';
import '../../domain/usecases/get_customers.dart';
import '../../domain/usecases/update_customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final dataSource = CustomerRemoteDataSource(
    SupabaseService.client,
  );

  return CustomerRepositoryImpl(dataSource);
});

final getCustomersProvider = Provider<GetCustomers>((ref) {
  return GetCustomers(
    ref.read(customerRepositoryProvider),
  );
});

final getCustomerProvider = Provider<GetCustomer>((ref) {
  return GetCustomer(
    ref.read(customerRepositoryProvider),
  );
});

final createCustomerProvider = Provider<CreateCustomer>((ref) {
  return CreateCustomer(
    ref.read(customerRepositoryProvider),
  );
});

final updateCustomerProvider = Provider<UpdateCustomer>((ref) {
  return UpdateCustomer(
    ref.read(customerRepositoryProvider),
  );
});

final deleteCustomerProvider = Provider<DeleteCustomer>((ref) {
  return DeleteCustomer(
    ref.read(customerRepositoryProvider),
  );
});

final customersProvider =
    AsyncNotifierProvider<CustomersNotifier, List<Customer>>(
  CustomersNotifier.new,
);

class CustomersNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() {
    return ref.read(getCustomersProvider).call();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => ref.read(getCustomersProvider).call(),
    );
  }

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final customer = Customer(
      id: '',
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );

    final created = await ref
        .read(createCustomerProvider)
        .call(customer);

    final current = state.value ?? <Customer>[];

    state = AsyncData([
      created,
      ...current,
    ]);

    return created;
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final updated = await ref
        .read(updateCustomerProvider)
        .call(customer);

    final current = state.value ?? <Customer>[];

    state = AsyncData(
      current.map((item) {
        return item.id == updated.id ? updated : item;
      }).toList(),
    );

    return updated;
  }

  Future<void> deleteCustomer(String id) async {
    await ref
        .read(deleteCustomerProvider)
        .call(id);

    final current = state.value ?? <Customer>[];

    state = AsyncData(
      current.where((customer) => customer.id != id).toList(),
    );
  }
}

final customerProvider =
    FutureProvider.family<Customer, String>((ref, id) {
  return ref.read(getCustomerProvider).call(id);
});
