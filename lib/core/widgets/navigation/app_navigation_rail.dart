import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/admin/presentation/providers/admin_providers.dart';
import '../../../features/shop/presentation/providers/shop_provider.dart';
import 'app_navigation_config.dart';
import 'navigation_parts.dart';

/// Tablet navigation: a slim icon rail with the full set of destinations
/// (labels as tooltips), grouped by section.
class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({
    super.key,
    required this.currentPath,
    required this.onSelect,
  });

  static const width = 76.0;

  final String? currentPath;
  final ValueChanged<NavDestination> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const SizedBox(height: AppSpacing.lg),
            const ShopLogoOnly(size: 40),
            const SizedBox(height: AppSpacing.md),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  for (final (index, entry) in sections.entries.indexed) ...[
                    if (index > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.sm,
                        ),
                        child: Divider(),
                      ),
                    for (final destination in entry.value)
                      _RailButton(
                        destination: destination,
                        selected: destination == active,
                        onTap: () => onSelect(destination),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: IconButton(
                tooltip: 'Sign Out',
                onPressed: () => confirmSignOut(context, ref),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = destination.isComingSoon
        ? '${destination.label} (coming soon)'
        : destination.label;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: Semantics(
            label: label,
            selected: selected,
            button: true,
            excludeSemantics: true,
            child: Material(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                hoverColor: AppColors.surfaceMuted,
                child: SizedBox(
                  width: 48,
                  height: 44,
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 21,
                    color: selected
                        ? AppColors.primary
                        : destination.isComingSoon
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
