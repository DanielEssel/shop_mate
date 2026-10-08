import 'package:flutter/material.dart';

/// Who may see a destination. UI only: the router and the database enforce
/// access regardless.
enum NavAccess { everyone, owner, platformAdmin }

enum NavSection {
  main('Main'),
  business('Business'),
  system('System');

  const NavSection(this.label);

  final String label;
}

/// One place in the app's navigation. Drives the bottom bar, drawer, rail
/// and sidebar so they always agree.
@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.section,
    this.route,
    this.access = NavAccess.everyone,
    this.branchIndex,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final NavSection section;

  /// Null for features that are not available yet ("coming soon").
  final String? route;

  final NavAccess access;

  /// The bottom-navigation tab this destination lives in, if any.
  final int? branchIndex;

  bool get isComingSoon => route == null;

  bool get isShellTab => branchIndex != null;

  bool isVisibleTo({required bool isOwner, required bool isPlatformAdmin}) {
    return switch (access) {
      NavAccess.everyone => true,
      NavAccess.owner => isOwner,
      NavAccess.platformAdmin => isPlatformAdmin,
    };
  }
}

/// A bottom navigation tab.
@immutable
class NavTab {
  const NavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

abstract final class AppNavigation {
  // ─────────────────────────────────────────────
  // MAIN
  // ─────────────────────────────────────────────

  static const dashboard = NavDestination(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    section: NavSection.main,
    route: '/dashboard',
    branchIndex: 0,
  );

  static const products = NavDestination(
    label: 'Products',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    section: NavSection.main,
    route: '/products',
    branchIndex: 1,
  );

  static const inventory = NavDestination(
    label: 'Inventory',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse_rounded,
    section: NavSection.main,
    route: '/inventory',
    branchIndex: 2,
  );

  static const sales = NavDestination(
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    section: NavSection.main,
    route: '/sales',
    branchIndex: 3,
  );

  static const customers = NavDestination(
    label: 'Customers',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group_rounded,
    section: NavSection.main,
    route: '/customers',
  );

  static const purchases = NavDestination(
    label: 'Purchases',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag_rounded,
    section: NavSection.main,
    route: '/purchases',
  );

  // ─────────────────────────────────────────────
  // BUSINESS
  // ─────────────────────────────────────────────

  static const suppliers = NavDestination(
    label: 'Suppliers',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
    section: NavSection.business,
    route: '/suppliers',
  );

  static const expenses = NavDestination(
    label: 'Expenses',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    section: NavSection.business,
    route: '/expenses',
    access: NavAccess.owner,
  );

  static const reports = NavDestination(
    label: 'Reports',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    section: NavSection.business,
    route: '/reports/business-performance',
    access: NavAccess.owner,
  );

  static const inventoryReport = NavDestination(
    label: 'Inventory Report',
    icon: Icons.assessment_outlined,
    selectedIcon: Icons.assessment_rounded,
    section: NavSection.business,
    route: '/reports/inventory',
    access: NavAccess.owner,
  );

  static const analytics = NavDestination(
    label: 'Analytics',
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics_rounded,
    section: NavSection.business,
    access: NavAccess.owner,
  );

  // ─────────────────────────────────────────────
  // SYSTEM
  // ─────────────────────────────────────────────

  static const settings = NavDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    section: NavSection.system,
    route: '/settings',
    access: NavAccess.owner,
  );

  static const platformAdmin = NavDestination(
    label: 'Platform Admin',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield_rounded,
    section: NavSection.system,
    route: '/admin',
    access: NavAccess.platformAdmin,
  );

  static const users = NavDestination(
    label: 'Users & Permissions',
    icon: Icons.manage_accounts_outlined,
    selectedIcon: Icons.manage_accounts_rounded,
    section: NavSection.system,
    route: '/users',
    access: NavAccess.owner,
  );

  static const notifications = NavDestination(
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications_rounded,
    section: NavSection.system,
  );

  static const help = NavDestination(
    label: 'Help & Support',
    icon: Icons.help_outline_rounded,
    selectedIcon: Icons.help_rounded,
    section: NavSection.system,
  );

  /// Every destination, in display order.
  static const all = [
    dashboard,
    products,
    inventory,
    sales,
    customers,
    purchases,
    suppliers,
    expenses,
    reports,
    inventoryReport,
    analytics,
    settings,
    platformAdmin,
    users,
    notifications,
    help,
  ];

  /// The phone bottom bar. Index matches the shell branch.
  static const tabs = [
    NavTab(
      label: 'Home',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
    ),
    NavTab(
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
    ),
    NavTab(
      label: 'Inventory',
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse_rounded,
    ),
    NavTab(
      label: 'Sales',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale_rounded,
    ),
    NavTab(
      label: 'More',
      icon: Icons.more_horiz_rounded,
      selectedIcon: Icons.more_horiz_rounded,
    ),
  ];

  /// Shell routes switch tabs; everything else opens above the shell.
  static const shellRoutes = {
    '/dashboard',
    '/products',
    '/inventory',
    '/sales',
    '/more',
  };

  /// Destinations [isOwner] / [isPlatformAdmin] may see, grouped by section
  /// in display order.
  static Map<NavSection, List<NavDestination>> visibleSections({
    required bool isOwner,
    required bool isPlatformAdmin,
  }) {
    final sections = <NavSection, List<NavDestination>>{
      for (final section in NavSection.values) section: [],
    };
    for (final destination in all) {
      if (destination.isVisibleTo(
        isOwner: isOwner,
        isPlatformAdmin: isPlatformAdmin,
      )) {
        sections[destination.section]!.add(destination);
      }
    }
    sections.removeWhere((_, items) => items.isEmpty);
    return sections;
  }

  /// The destination that [path] belongs to (longest route prefix wins), or
  /// null (e.g. /more).
  static NavDestination? activeFor(String? path) {
    if (path == null) return null;
    NavDestination? best;
    for (final destination in all) {
      final route = destination.route;
      if (route == null) continue;
      final matches = path == route || path.startsWith('$route/');
      if (matches && (best == null || route.length > best.route!.length)) {
        best = destination;
      }
    }
    return best;
  }
}
