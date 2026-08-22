import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../data/datasources/sales_remote_datasource.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/usecases/create_sale.dart';
import '../../domain/usecases/get_sale.dart';
import '../../domain/usecases/get_sales.dart';
import '../../domain/entities/sale_item.dart';

final salesRemoteDataSourceProvider =
    Provider<SalesRemoteDataSource>((ref) {
  return SalesRemoteDataSource(
    SupabaseService.client,
  );
});

final salesRepositoryProvider =
    Provider<SaleRepository>((ref) {
  return SalesRepositoryImpl(
    ref.read(salesRemoteDataSourceProvider),
  );
});

final createSaleProvider =
    Provider<CreateSale>((ref) {
  return CreateSale(
    ref.read(salesRepositoryProvider),
  );
});

final getSalesProvider =
    Provider<GetSales>((ref) {
  return GetSales(
    ref.read(salesRepositoryProvider),
  );
});

final getSaleProvider =
    Provider<GetSale>((ref) {
  return GetSale(
    ref.read(salesRepositoryProvider),
  );
});

final salesProvider =
    FutureProvider<List<Sale>>((ref) {
  return ref.read(getSalesProvider).call();
});

final saleProvider =
    FutureProvider.family<Sale, String>((ref, id) {
  return ref.read(getSaleProvider).call(id);
});

final saleItemsProvider =
    FutureProvider.family<List<SaleItem>, String>((ref, saleId) async {
  final dataSource = ref.read(salesRemoteDataSourceProvider);

  return dataSource.getSaleItems(saleId);
});

final salesProductsProvider =
    FutureProvider<List<Product>>((ref) async {
  return ref.watch(productsProvider.future);
});

class SaleCartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [];
  }

  void addProduct(Product product) {
    if (product.stockQuantity <= 0) {
      return;
    }

    final index = state.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (index == -1) {
      state = [
        ...state,
        CartItem(
          product: product,
          quantity: 1,
        ),
      ];
      return;
    }

    final existing = state[index];

    if (existing.quantity >= product.stockQuantity) {
      return;
    }

    final updatedItems = [...state];

    updatedItems[index] = existing.copyWith(
      quantity: existing.quantity + 1,
    );

    state = updatedItems;
  }

  void increaseQuantity(String productId) {
    final index = state.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index == -1) {
      return;
    }

    final item = state[index];

    if (item.quantity >= item.product.stockQuantity) {
      return;
    }

    final updatedItems = [...state];

    updatedItems[index] = item.copyWith(
      quantity: item.quantity + 1,
    );

    state = updatedItems;
  }

  void decreaseQuantity(String productId) {
    final index = state.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index == -1) {
      return;
    }

    final item = state[index];

    if (item.quantity <= 1) {
      removeProduct(productId);
      return;
    }

    final updatedItems = [...state];

    updatedItems[index] = item.copyWith(
      quantity: item.quantity - 1,
    );

    state = updatedItems;
  }

  void removeProduct(String productId) {
    state = state
        .where(
          (item) => item.product.id != productId,
        )
        .toList();
  }

  void clearCart() {
    state = [];
  }

  double get subtotal {
    return state.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
  }

  double get discount {
    return 0;
  }

  double get total {
    return subtotal - discount;
  }
}

final saleCartProvider =
    NotifierProvider<SaleCartNotifier, List<CartItem>>(
  SaleCartNotifier.new,
);
