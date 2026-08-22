import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/navigation/app_shell.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/inventory/presentation/screens/stock_adjustment_screen.dart';
import '../../features/inventory/presentation/screens/stock_history_screen.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/products/presentation/screens/product_details_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/sales/presentation/screens/new_sale_screen.dart';
import '../../features/sales/presentation/screens/sale_details_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/customers/presentation/screens/add_customer_screen.dart';
import '../../features/customers/presentation/screens/customer_details_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/products/domain/entities/product.dart';
import '../../features/purchases/presentation/screens/purchases_screen.dart';
import '../../features/purchases/presentation/screens/new_purchase_screen.dart';
import '../../features/purchases/presentation/screens/purchase_details_screen.dart';
import '../../features/inventory/presentation/screens/low_stock_screen.dart';
import '../../features/products/presentation/screens/product_edit_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/dashboard',

  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),

  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthenticated = session != null;

    final isAuthRoute =
        state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    if (!isAuthenticated && !isAuthRoute) {
      return '/login';
    }

    if (isAuthenticated && isAuthRoute) {
      return '/dashboard';
    }

    return null;
  },

  routes: [
    // =============================================================
    // AUTH
    // =============================================================
    GoRoute(
      path: '/login',
      builder: (context, state) {
        return const LoginScreen();
      },
    ),

    GoRoute(
      path: '/signup',
      builder: (context, state) {
        return const SignupScreen();
      },
    ),

    // =============================================================
    // MAIN APPLICATION
    // =============================================================
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // =========================================================
        // 0. DASHBOARD
        // =========================================================
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) {
                return const DashboardScreen();
              },
            ),
          ],
        ),

        // =========================================================
        // 1. PRODUCTS
        // =========================================================
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              builder: (context, state) {
                return const ProductsScreen();
              },

              routes: [
  GoRoute(
    path: 'new',
    builder: (context, state) {
      return const AddProductScreen();
    },
  ),

  GoRoute(
    path: 'edit',
    builder: (context, state) {
      final product = state.extra as Product;

      return EditProductScreen(
        product: product,
      );
    },
  ),

  GoRoute(
    path: ':productId',
    builder: (context, state) {
      final productId = state.pathParameters['productId']!;

      return ProductDetailsScreen(
        productId: productId,
      );
    },
  ),
],
            ),
          ],
        ),

        // =========================================================
        // 2. INVENTORY
        // =========================================================
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              builder: (context, state) {
                return const InventoryScreen();
              },
              routes: [
                GoRoute(
                  path: 'low-stock',
                  builder: (context, state) {
                    return const LowStockScreen();
                  },
                ),

                GoRoute(
                  path: 'adjust',
                  builder: (context, state) {
                    final product = state.extra as Product?;

                    return StockAdjustmentScreen(product: product);
                  },
                ),

                GoRoute(
                  path: 'history',
                  builder: (context, state) {
                    return const StockHistoryScreen();
                  },
                ),
              ],
            ),
          ],
        ),

        // =========================================================
        // 3. SALES
        // =========================================================
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sales',
              builder: (context, state) {
                return const SalesScreen();
              },
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) {
                    return const NewSaleScreen();
                  },
                ),
                GoRoute(
                  path: ':saleId',
                  builder: (context, state) {
                    final saleId = state.pathParameters['saleId']!;

                    return SaleDetailsScreen(saleId: saleId);
                  },
                ),
              ],
            ),
          ],
        ),

        // =========================================================
        // 4. MORE
        // =========================================================
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) {
                return const MoreScreen();
              },
            ),
          ],
        ),
      ],
    ),

    // =============================================================
    // CUSTOMERS
    // =============================================================
    GoRoute(
      path: '/customers',
      builder: (context, state) {
        return const CustomersScreen();
      },
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) {
            return const AddCustomerScreen();
          },
        ),
        GoRoute(
          path: ':customerId',
          builder: (context, state) {
            final customerId = state.pathParameters['customerId']!;

            return CustomerDetailsScreen(customerId: customerId);
          },
        ),
      ],
    ),

    // =============================================================
    // PURCHASES
    // =============================================================
    GoRoute(
      path: '/purchases',
      builder: (context, state) {
        return const PurchasesScreen();
      },
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) {
            return const NewPurchaseScreen();
          },
        ),
        GoRoute(
          path: ':purchaseId',
          builder: (context, state) {
            final purchaseId = state.pathParameters['purchaseId']!;

            return PurchaseDetailsScreen(purchaseId: purchaseId);
          },
        ),
      ],
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
