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
///
/// On short windows (tablet landscape) the destinations scroll between the
/// fixed identity and Sign Out; the scrollbar shows there is more, and the
/// active destination is scrolled into view so it is never left half-hidden
/// at the footer.
class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.onSelect,
  });

  static const width = 248.0;

  final String? currentPath;
  final ValueChanged<NavDestination> onSelect;

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  final _scroll = ScrollController();
  final _activeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealActive();
  }

  @override
  void didUpdateWidget(AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) _revealActive();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls just enough to show the active destination whole; does nothing
  /// when it is already visible.
  void _revealActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _activeKey.currentContext;
      if (!mounted || target == null) return;
      for (final policy in const [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(target, alignmentPolicy: policy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Owner-only destinations are hidden from attendants; the router and the
    // database refuse them as well.
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));
    final isPlatformAdmin = ref.watch(isPlatformAdminProvider).isConfirmedAdmin;

    final sections = AppNavigation.visibleSections(
      isOwner: isOwner,
      isPlatformAdmin: isPlatformAdmin,
    );
    final active = AppNavigation.activeFor(widget.currentPath);

    return Container(
      width: AppSidebar.width,
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
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: ListView(
                  controller: _scroll,
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
                          key: destination == active ? _activeKey : null,
                          label: destination.label,
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          selected: destination == active,
                          comingSoon: destination.isComingSoon,
                          onTap: () => widget.onSelect(destination),
                        ),
                    ],
                  ],
                ),
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
