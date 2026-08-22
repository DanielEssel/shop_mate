import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../data/datasources/purchase_remote_datasource.dart';
import '../../data/repositories/purchase_repository_impl.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/purchase_cart_item.dart';
import '../../domain/entities/purchase_item.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../domain/usecases/create_purchase.dart';
import '../../domain/usecases/get_purchase.dart';
import '../../domain/usecases/get_purchases.dart';

final purchaseRemoteDataSourceProvider =
    Provider<PurchaseRemoteDataSource>((ref) {
  return PurchaseRemoteDataSource(
    SupabaseService.client,
  );
});

final purchaseRepositoryProvider =
    Provider<PurchaseRepository>((ref) {
  return PurchaseRepositoryImpl(
    ref.read(purchaseRemoteDataSourceProvider),
  );
});

final createPurchaseProvider =
    Provider<CreatePurchase>((ref) {
  return CreatePurchase(
    ref.read(purchaseRepositoryProvider),
  );
});

final getPurchasesProvider =
    Provider<GetPurchases>((ref) {
  return GetPurchases(
    ref.read(purchaseRepositoryProvider),
  );
});

final getPurchaseProvider =
    Provider<GetPurchase>((ref) {
  return GetPurchase(
    ref.read(purchaseRepositoryProvider),
  );
});

final purchasesProvider =
    FutureProvider<List<Purchase>>((ref) {
  return ref.read(getPurchasesProvider).call();
});

final purchaseProvider =
    FutureProvider.family<Purchase, String>((ref, id) {
  return ref.read(getPurchaseProvider).call(id);
});

final purchaseItemsProvider =
    FutureProvider.family<List<PurchaseItem>, String>(
  (ref, purchaseId) async {
    final dataSource =
        ref.read(purchaseRemoteDataSourceProvider);

    return dataSource.getPurchaseItems(purchaseId);
  },
);

final purchaseProductsProvider =
    FutureProvider<List<Product>>((ref) async {
  return ref.watch(productsProvider.future);
});

class PurchaseCartNotifier
    extends Notifier<List<PurchaseCartItem>> {
  @override
  List<PurchaseCartItem> build() {
    return [];
  }

  void addProduct(Product product) {
    final index = state.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (index == -1) {
      state = [
        ...state,
        PurchaseCartItem(
          product: product,
          quantity: 1,
          unitCost: product.costPrice,
        ),
      ];
      return;
    }

    increaseQuantity(product.id);
  }

  void increaseQuantity(String productId) {
    final index = state.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index == -1) {
      return;
    }

    final item = state[index];

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

  void updateQuantity(
    String productId,
    int quantity,
  ) {
    final index = state.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index == -1) {
      return;
    }

    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final updatedItems = [...state];

    updatedItems[index] = updatedItems[index].copyWith(
      quantity: quantity,
    );

    state = updatedItems;
  }

  void updateUnitCost(
    String productId,
    double unitCost,
  ) {
    final index = state.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index == -1) {
      return;
    }

    if (unitCost < 0) {
      return;
    }

    final updatedItems = [...state];

    updatedItems[index] = updatedItems[index].copyWith(
      unitCost: unitCost,
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

  double get total {
    return subtotal;
  }

  int get totalItems {
    return state.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

  }
}

final purchaseCartProvider =
    NotifierProvider<
      PurchaseCartNotifier,
      List<PurchaseCartItem>
    >(
  PurchaseCartNotifier.new,
);