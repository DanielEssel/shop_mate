import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../shop/presentation/providers/shop_branding_providers.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../../shop/presentation/widgets/shop_logo_mark.dart';

/// Shop context, today's date and the greeting.
///
/// On desktop the sidebar already shows the shop, so only the greeting
/// remains here.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String dateLabel(DateTime now) {
    return '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final showShop = !Breakpoints.ofWindow(context).isAtLeastExpanded;

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
    final hasShopName = shopName != null && shopName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (AppMenuButton.isVisible(context) || (showShop && hasShopName)) ...[
          Row(
            children: [
              const AppMenuButton(),
              if (AppMenuButton.isVisible(context))
                const SizedBox(width: AppSpacing.xs),
              if (showShop && hasShopName) ...[
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
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        OverlineText(dateLabel(now)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          greeting(now),
          style: textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Here is what is happening in your shop today.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
