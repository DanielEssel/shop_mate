import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../features/admin/presentation/providers/admin_providers.dart';
import '../../../features/shop/presentation/providers/shop_provider.dart';
import 'app_navigation_config.dart';
import 'navigation_parts.dart';

/// The phone navigation drawer: every destination the account may see,
/// grouped Main / Business / System, with the current one highlighted.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Owner-only destinations are hidden from attendants; the router and the
    // database refuse them as well.
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));
    // Platform admins only; the database still checks every admin action.
    final isPlatformAdmin = ref.watch(isPlatformAdminProvider).isConfirmedAdmin;

    final sections = AppNavigation.visibleSections(
      isOwner: isOwner,
      isPlatformAdmin: isPlatformAdmin,
    );
    final active = AppNavigation.activeFor(
      GoRouter.maybeOf(context)?.state.uri.path,
    );

    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: ShopIdentity(logoSize: 44, nameMaxLines: 2),
            ),

            const Divider(),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                children: [
                  for (final entry in sections.entries) ...[
                    NavSectionLabel(entry.key.label.toUpperCase()),
                    for (final destination in entry.value)
                      NavItemTile(
                        label: destination.label,
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        selected: destination == active,
                        comingSoon: destination.isComingSoon,
                        onTap: () => _open(context, destination),
                      ),
                  ],
                ],
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: NavItemTile(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                destructive: true,
                onTap: () => confirmSignOut(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _open(BuildContext context, NavDestination destination) {
    Navigator.of(context).pop();

    final route = destination.route;
    if (route == null) {
      showComingSoon(context, destination.label);
      return;
    }

    // Tabs switch inside the shell; everything else opens above it so Back
    // returns to where the user was.
    if (AppNavigation.shellRoutes.contains(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }
}
