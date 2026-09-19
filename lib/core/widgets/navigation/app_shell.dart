import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_bottom_navigation.dart';
import 'app_navigation_rail.dart';
import 'app_drawer.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= 1100) {
          return _DesktopShell(
            navigationShell: navigationShell,
            onDestinationSelected: _goToBranch,
          );
        }

        if (width >= 700) {
          return _TabletShell(
            navigationShell: navigationShell,
            onDestinationSelected: _goToBranch,
          );
        }

        return _MobileShell(
          navigationShell: navigationShell,
          onDestinationSelected: _goToBranch,
        );
      },
    );
  }
}

// ================================================================
// MOBILE
// ================================================================

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.navigationShell,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}

// ================================================================
// TABLET
// ================================================================

class _TabletShell extends StatelessWidget {
  const _TabletShell({
    required this.navigationShell,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Row(
        children: [
          AppNavigationRail(
            currentIndex: navigationShell.currentIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

// ================================================================
// DESKTOP
// ================================================================

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.navigationShell,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Row(
        children: [
          AppNavigationRail(
            currentIndex: navigationShell.currentIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
