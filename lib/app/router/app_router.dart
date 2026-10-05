import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/navigation/app_shell.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/customers/presentation/screens/add_customer_screen.dart';
import '../../features/customers/presentation/screens/customer_details_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/expenses/presentation/screens/expense_details_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/inventory/presentation/screens/low_stock_screen.dart';
import '../../features/inventory/presentation/screens/stock_adjustment_screen.dart';
import '../../features/inventory/presentation/screens/stock_history_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/products/domain/entities/product.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/products/presentation/screens/product_details_screen.dart';
import '../../features/products/presentation/screens/product_edit_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/reports/presentation/screens/business_performance_screen.dart';
import '../../features/reports/presentation/screens/inventory_report_screen.dart';
import '../../features/purchases/presentation/screens/new_purchase_screen.dart';
import '../../features/purchases/presentation/screens/purchase_details_screen.dart';
import '../../features/purchases/presentation/screens/purchases_screen.dart';
import '../../features/sales/presentation/screens/new_sale_screen.dart';
import '../../features/sales/presentation/screens/receipt_preview_screen.dart';
import '../../features/sales/presentation/screens/sale_details_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/shop/domain/entities/shop_access.dart';
import '../../features/shop/presentation/providers/shop_provider.dart';
import '../../features/shop/presentation/screens/register_shop_screen.dart';
import '../../features/shop/presentation/screens/shop_status_screens.dart';

const Set<String> _authRoutes = {'/login', '/signup'};

/// Screens a signed-in user can be parked on while their shop access is
/// sorted out. None of them show business data.
const Set<String> _statusRoutes = {
  '/register-shop',
  '/pending',
  '/suspended',
  '/access-error',
};

const String _loadingRoute = '/loading';

/// The app-wide navigator. Detail routes that must open above both the shell
/// and the root-level screens (e.g. Customer Details) are attached here.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// The app router. It is a provider (not a global) so its redirect can read
/// the signed-in user's shop access.
///
/// Access rules:
///   signed out            -> /login or /signup only
///   signed in, no shop    -> /register-shop
///   shop pending          -> /pending
///   shop or member paused -> /suspended
///   status unknown        -> /access-error (retry)
///   shop active           -> the app
final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  final accessRefresh = _RouterRefresh();

  // Re-run the redirect whenever the shop access answer changes. Only
  // listen here (never watch), so the router itself is created once.
  ref.listen<AsyncValue<ShopAccess>>(
    shopAccessProvider,
    (_, _) => accessRefresh.notify(),
  );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',

    refreshListenable: Listenable.merge([authRefresh, accessRefresh]),

    redirect: (context, state) => _redirect(ref, state),

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
      // SHOP ACCESS GATE
      // =============================================================
      GoRoute(
        path: _loadingRoute,
        builder: (context, state) {
          return const AccessLoadingScreen();
        },
      ),

      GoRoute(
        path: '/register-shop',
        builder: (context, state) {
          return const RegisterShopScreen();
        },
      ),

      GoRoute(
        path: '/pending',
        builder: (context, state) {
          return const PendingApprovalScreen();
        },
      ),

      GoRoute(
        path: '/suspended',
        builder: (context, state) {
          return const SuspendedScreen();
        },
      ),

      GoRoute(
        path: '/access-error',
        builder: (context, state) {
          return const AccessErrorScreen();
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

                      return EditProductScreen(product: product);
                    },
                  ),
                  GoRoute(
                    path: ':productId',
                    builder: (context, state) {
                      final productId = state.pathParameters['productId']!;

                      return ProductDetailsScreen(productId: productId);
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
                  // On the root navigator so it can be pushed from screens
                  // outside the shell (Customer Details -> Credit Statement)
                  // without go_router appending a second copy of this
                  // StatefulShellRoute, whose duplicate GlobalKeys assert.
                  // Its receipt child must use the same navigator so it opens
                  // above the details page instead of underneath it.
                  GoRoute(
                    path: ':saleId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final saleId = state.pathParameters['saleId']!;

                      return SaleDetailsScreen(saleId: saleId);
                    },
                    routes: [
                      GoRoute(
                        path: 'receipt',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final saleId = state.pathParameters['saleId']!;

                          return ReceiptPreviewScreen(saleId: saleId);
                        },
                      ),
                    ],
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

      // =============================================================
      // EXPENSES
      // =============================================================
      // Root-level like Customers/Purchases: history and details stack on
      // the root navigator, outside the StatefulShellRoute.
      GoRoute(
        path: '/expenses',
        builder: (context, state) {
          return const ExpensesScreen();
        },
        routes: [
          GoRoute(
            path: ':expenseId',
            builder: (context, state) {
              final expenseId = state.pathParameters['expenseId']!;

              return ExpenseDetailsScreen(expenseId: expenseId);
            },
          ),
        ],
      ),

      // =============================================================
      // REPORTS
      // =============================================================
      // Root-level like Expenses: opened from More and stacked on the root
      // navigator, outside the StatefulShellRoute.
      GoRoute(
        path: '/reports/business-performance',
        builder: (context, state) {
          return const BusinessPerformanceScreen();
        },
      ),
      GoRoute(
        path: '/reports/inventory',
        builder: (context, state) {
          return const InventoryReportScreen();
        },
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    authRefresh.dispose();
    accessRefresh.dispose();
  });

  return router;
});

String? _redirect(Ref ref, GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  final location = state.matchedLocation;
  final isAuthRoute = _authRoutes.contains(location);

  // Signed out: only the auth screens.
  if (session == null) {
    return isAuthRoute ? null : '/login';
  }

  final access = ref.read(shopAccessProvider);
  final data = access.value;

  // Only trust an answer that is finished loading AND belongs to the
  // account that is signed in right now. Anything else could be a leftover
  // from a previous user and must never grant (or wrongly deny) access.
  if (access.isLoading || data == null || data.userId != session.user.id) {
    // Still working it out. Status screens stay put (e.g. while "Check
    // status" reloads); everything else waits on the splash so no business
    // screen builds before we know the account may see it.
    if (location == _loadingRoute || _statusRoutes.contains(location)) {
      return null;
    }

    return _loadingRoute;
  }

  final target = switch (data.status) {
    ShopAccessStatus.noShop => '/register-shop',
    ShopAccessStatus.pending => '/pending',
    ShopAccessStatus.suspended => '/suspended',
    ShopAccessStatus.unavailable => '/access-error',
    ShopAccessStatus.active => null,
  };

  if (target != null) {
    return location == target ? null : target;
  }

  // Active shop: leave the auth / gate screens for the app.
  if (isAuthRoute ||
      location == _loadingRoute ||
      _statusRoutes.contains(location)) {
    return '/dashboard';
  }

  return null;
}

/// Lets the provider listener above poke the router to re-run its redirect.
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

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
