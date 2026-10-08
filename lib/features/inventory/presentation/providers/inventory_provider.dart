import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/inventory_remote_datasource.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/inventory_summary.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/adjust_stock.dart';
import '../../domain/usecases/get_inventory_summary.dart';
import '../../domain/usecases/get_stock_movements.dart';

final inventoryRemoteDataSourceProvider = Provider<InventoryRemoteDataSource>((
  ref,
) {
  return InventoryRemoteDataSource(Supabase.instance.client);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(ref.read(inventoryRemoteDataSourceProvider));
});

final adjustStockProvider = Provider<AdjustStock>((ref) {
  return AdjustStock(ref.read(inventoryRepositoryProvider));
});

final getInventorySummaryProvider = Provider<GetInventorySummary>((ref) {
  return GetInventorySummary(ref.read(inventoryRepositoryProvider));
});

final getStockMovementsProvider = Provider<GetStockMovements>((ref) {
  return GetStockMovements(ref.read(inventoryRepositoryProvider));
});

final inventorySummaryProvider = FutureProvider<InventorySummary>((ref) {
  // Session-scoped: rebuilt when the signed-in account changes.
  ref.watch(currentUserIdProvider);

  return ref.read(getInventorySummaryProvider).call();
});

final stockMovementsProvider = FutureProvider<List<StockMovement>>((ref) {
  ref.watch(currentUserIdProvider);

  return ref.read(getStockMovementsProvider).call();
});

final productStockMovementsProvider =
    FutureProvider.family<List<StockMovement>, String>((ref, productId) {
      ref.watch(currentUserIdProvider);

      return ref.read(getStockMovementsProvider).call(productId: productId);
    });
