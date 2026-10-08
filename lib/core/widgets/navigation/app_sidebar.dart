import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/admin/presentation/providers/admin_providers.dart';
import '../../../features/shop/presentation/providers/shop_provider.dart';
import 'app_navigation_config.dart';
import 'navigation_parts.dart';

/// Persistent desktop navigation: shop identity, every destination the
/// account may see (Main / Business / System), and Sign Out.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.onSelect,
  });

  static const width = 248.0;

  final String? currentPath;
  final ValueChanged<NavDestination> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Owner-only destinations are hidden from attendants; the router and the
    // database refuse them as well.
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));
    final isPlatformAdmin = ref.watch(isPlatformAdminProvider).isConfirmedAdmin;

    final sections = AppNavigation.visibleSections(
      isOwner: isOwner,
      isPlatformAdmin: isPlatformAdmin,
    );
    final active = AppNavigation.activeFor(currentPath);

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: ShopIdentity(logoSize: 36),
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
                        onTap: () => onSelect(destination),
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
}
