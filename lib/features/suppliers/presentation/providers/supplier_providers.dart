import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/supplier_remote_datasource.dart';
import '../../data/repositories/supplier_repository_impl.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../../domain/usecases/create_supplier.dart';
import '../../domain/usecases/get_supplier.dart';
import '../../domain/usecases/get_suppliers.dart';
import '../../domain/usecases/update_supplier.dart';

final supplierRemoteDataSourceProvider = Provider<SupplierRemoteDataSource>((
  ref,
) {
  return SupplierRemoteDataSource(SupabaseService.client);
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepositoryImpl(ref.read(supplierRemoteDataSourceProvider));
});

final getSuppliersProvider = Provider<GetSuppliers>((ref) {
  return GetSuppliers(ref.read(supplierRepositoryProvider));
});

final getSupplierProvider = Provider<GetSupplier>((ref) {
  return GetSupplier(ref.read(supplierRepositoryProvider));
});

final createSupplierProvider = Provider<CreateSupplier>((ref) {
  return CreateSupplier(ref.read(supplierRepositoryProvider));
});

final updateSupplierProvider = Provider<UpdateSupplier>((ref) {
  return UpdateSupplier(ref.read(supplierRepositoryProvider));
});

/// Active suppliers of the current shop, ordered by name. Auto-disposed so
/// each visit reads fresh data.
final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) {
  return ref.read(getSuppliersProvider).call();
});

/// Which suppliers the supplier list shows.
enum SupplierStatusFilter {
  active('Active'),
  inactive('Inactive'),
  all('All');

  const SupplierStatusFilter(this.label);

  final String label;
}

/// Suppliers for one status filter, ordered by name. Inactive and All read
/// every supplier from the server; Inactive then keeps only inactive ones.
final suppliersByStatusProvider = FutureProvider.autoDispose
    .family<List<Supplier>, SupplierStatusFilter>((ref, filter) async {
      final getSuppliers = ref.read(getSuppliersProvider);

      return switch (filter) {
        SupplierStatusFilter.active => getSuppliers(),
        SupplierStatusFilter.all => getSuppliers(includeInactive: true),
        SupplierStatusFilter.inactive => (await getSuppliers(
          includeInactive: true,
        )).where((supplier) => !supplier.isActive).toList(growable: false),
      };
    });

/// Refreshes every supplier list and the given supplier after a write.
void invalidateSupplierData(WidgetRef ref, {String? supplierId}) {
  ref.invalidate(suppliersProvider);
  ref.invalidate(suppliersByStatusProvider);
  if (supplierId != null) {
    ref.invalidate(supplierProvider(supplierId));
  }
}

final supplierProvider = FutureProvider.autoDispose.family<Supplier, String>((
  ref,
  id,
) {
  return ref.read(getSupplierProvider).call(id);
});
