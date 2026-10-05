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

final supplierProvider = FutureProvider.autoDispose.family<Supplier, String>((
  ref,
  id,
) {
  return ref.read(getSupplierProvider).call(id);
});
