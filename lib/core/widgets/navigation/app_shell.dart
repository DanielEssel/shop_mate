import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/shop/domain/entities/shop_access.dart';
import '../../../features/shop/presentation/providers/shop_provider.dart';
import '../../ui/app_shell_scope.dart';
import '../../ui/layout/breakpoints.dart';
import 'app_bottom_navigation.dart';
import 'app_drawer.dart';
import 'app_navigation_config.dart';
import 'app_navigation_rail.dart';
import 'app_sidebar.dart';
import 'navigation_parts.dart';

/// The main tabs (Dashboard, Products, Inventory, Sales, More).
///
/// Phone: bottom navigation + drawer. Tablet: icon rail. Desktop:
/// persistent sidebar.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell,
    required this.currentPath,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final String currentPath;

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _select(BuildContext context, NavDestination destination) {
    final branch = destination.branchIndex;
    if (branch != null) {
      _goToBranch(branch);
      return;
    }
    openDestination(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.ofWindow(context);

    if (size.isCompact) {
      return Scaffold(
        drawer: const AppDrawer(),
        body: Builder(
          builder: (scaffoldContext) {
            return AppShellScope(
              openDrawer: () => Scaffold.of(scaffoldContext).openDrawer(),
              child: navigationShell,
            );
          },
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: navigationShell.currentIndex,
          onDestinationSelected: _goToBranch,
        ),
      );
    }

    return _WideFrame(
      size: size,
      currentPath: currentPath,
      onSelect: (destination) => _select(context, destination),
      child: navigationShell,
    );
  }
}

/// Secondary areas (Customers, Purchases, Suppliers, Expenses, Reports,
/// Settings, Users, Admin) keep the rail or sidebar from tablet width up.
/// On phones they are plain full-screen pages, as before.
class SecondaryShell extends ConsumerWidget {
  const SecondaryShell({
    required this.child,
    required this.currentPath,
    super.key,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = Breakpoints.ofWindow(context);

    // Navigation belongs to an active shop. A platform admin without one
    // (reaching /admin) gets the page alone.
    final hasActiveShop = ref.watch(
      shopAccessProvider.select(
        (access) => access.value?.status == ShopAccessStatus.active,
      ),
    );

    if (size.isCompact || !hasActiveShop) return child;

    return _WideFrame(
      size: size,
      currentPath: currentPath,
      onSelect: (destination) => openDestination(context, destination),
      child: child,
    );
  }
}

class _WideFrame extends StatelessWidget {
  const _WideFrame({
    required this.size,
    required this.currentPath,
    required this.onSelect,
    required this.child,
  });

  final WindowSize size;
  final String currentPath;
  final ValueChanged<NavDestination> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (size.isAtLeastExpanded)
            AppSidebar(currentPath: currentPath, onSelect: onSelect)
          else
            AppNavigationRail(currentPath: currentPath, onSelect: onSelect),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Persistent navigation: switching areas replaces the current one rather
/// than stacking pages.
void openDestination(BuildContext context, NavDestination destination) {
  final route = destination.route;
  if (route == null) {
    showComingSoon(context, destination.label);
    return;
  }
  context.go(route);
}

/// A page for the shells: no transition on wide windows (the navigation
/// stays put while the content swaps), the platform transition on phones
/// (including the iOS back swipe).
Page<void> adaptiveShellPage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (Breakpoints.ofWindow(context).isAtLeastMedium) return child;

      final route = ModalRoute.of(context);
      if (route is! PageRoute<Object?>) return child;

      return Theme.of(context).pageTransitionsTheme.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    },
  );
}
