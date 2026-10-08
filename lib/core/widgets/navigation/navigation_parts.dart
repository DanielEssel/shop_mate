import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/shop/presentation/providers/shop_branding_providers.dart';
import '../../../features/shop/presentation/providers/shop_provider.dart';
import '../../../features/shop/presentation/widgets/shop_logo_mark.dart';
import '../../ui/dialogs.dart';
import '../../ui/status_badge.dart';

/// Shop identity from the shared branding state. Branding is non-blocking:
/// while it loads or if it fails, the shop access name (or "ShopMate") and
/// the initial/icon fallback are shown.
class ShopIdentity extends ConsumerWidget {
  const ShopIdentity({
    super.key,
    this.logoSize = 40,
    this.nameMaxLines = 1,
    this.showSubtitle = true,
  });

  final double logoSize;
  final int nameMaxLines;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final email = ref.read(authRepositoryProvider).currentUser?.email;
    final brandingAsync = ref.watch(shopBrandingProvider);
    // unwrapPrevious: while reloading for a new account or shop, never show
    // the branding kept from the previous one.
    final branding = brandingAsync.unwrapPrevious().value;
    final accessName = ref.watch(
      shopAccessProvider.select((access) => access.value?.shopName),
    );
    final shopName =
        _nonEmpty(branding?.branding.name) ?? _nonEmpty(accessName);
    final phone = _nonEmpty(branding?.branding.phone);

    return Row(
      children: [
        ShopLogoMark(
          shopName: shopName,
          logoBytes: branding?.logoBytes,
          isLoading: brandingAsync.isLoading && branding == null,
          size: logoSize,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shopName ?? 'ShopMate',
                maxLines: nameMaxLines,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (showSubtitle)
                Text(
                  phone ?? email ?? 'Business Management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Just the shop's logo mark (for the compact rail).
class ShopLogoOnly extends ConsumerWidget {
  const ShopLogoOnly({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(shopBrandingProvider);
    final branding = brandingAsync.unwrapPrevious().value;
    final accessName = ref.watch(
      shopAccessProvider.select((access) => access.value?.shopName),
    );
    final shopName =
        _nonEmpty(branding?.branding.name) ?? _nonEmpty(accessName);

    return Tooltip(
      message: shopName ?? 'ShopMate',
      child: ShopLogoMark(
        shopName: shopName,
        logoBytes: branding?.logoBytes,
        isLoading: brandingAsync.isLoading && branding == null,
        size: size,
      ),
    );
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// A navigation entry with a clear selected state: green accent bar, green
/// icon and label, soft tint.
class NavItemTile extends StatelessWidget {
  const NavItemTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selectedIcon,
    this.selected = false,
    this.comingSoon = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final VoidCallback onTap;
  final bool selected;
  final bool comingSoon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Color foreground;
    final Color iconColor;
    if (destructive) {
      foreground = AppColors.danger;
      iconColor = AppColors.danger;
    } else if (selected) {
      foreground = AppColors.primaryDark;
      iconColor = AppColors.primary;
    } else {
      foreground = AppColors.textPrimary;
      iconColor = AppColors.textSecondary;
    }

    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: selected ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: AppColors.surfaceMuted,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  // Accent bar: the unmistakable selected marker.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md - 3 + AppSpacing.xs),
                  Icon(
                    selected ? (selectedIcon ?? icon) : icon,
                    size: 20,
                    color: comingSoon ? AppColors.textMuted : iconColor,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: comingSoon
                            ? AppColors.textSecondary
                            : foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (comingSoon)
                    const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: StatusBadge(
                        label: 'Soon',
                        tone: StatusTone.neutral,
                        showDot: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section label inside navigation ("MAIN", "BUSINESS", "SYSTEM").
class NavSectionLabel extends StatelessWidget {
  const NavSectionLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Tells the user a destination is not available yet.
void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature is coming soon.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Confirms, then signs out. Clearing the session resets every
/// account-scoped provider, and the router then replaces the whole app with
/// Login.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final shouldSignOut = await showConfirmDialog(
    context,
    title: 'Sign out?',
    message: 'Are you sure you want to sign out of ShopMate?',
    confirmLabel: 'Sign Out',
  );

  if (!shouldSignOut || !context.mounted) {
    return;
  }

  await ref.read(authSessionProvider.notifier).signOut();
}
