import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../shop/presentation/providers/shop_branding_providers.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../../shop/presentation/widgets/shop_logo_mark.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 17) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Branding never blocks the dashboard: while it loads or if it fails,
    // the shop access name and the initial/icon fallback are shown.
    final brandingAsync = ref.watch(shopBrandingProvider);
    // unwrapPrevious: while reloading for a new account or shop, never show
    // the branding kept from the previous one.
    final branding = brandingAsync.unwrapPrevious().value;
    final accessName = ref.watch(
      shopAccessProvider.select((access) => access.value?.shopName),
    );
    final brandName = branding?.branding.name.trim();
    final shopName = brandName != null && brandName.isNotEmpty
        ? brandName
        : accessName?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Open menu',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              icon: const Icon(Icons.menu_rounded),
              color: AppColors.textPrimary,
              iconSize: 28,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            );
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shopName != null && shopName.isNotEmpty) ...[
                Row(
                  children: [
                    ShopLogoMark(
                      shopName: shopName,
                      logoBytes: branding?.logoBytes,
                      isLoading: brandingAsync.isLoading && branding == null,
                      size: 32,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        shopName,
                        key: const ValueKey('dashboard-shop-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                '${_greeting()} 👋',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Here is what is happening in your shop today.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
