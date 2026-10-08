import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../shop/presentation/providers/shop_provider.dart';

/// Everything that isn't a bottom-navigation tab, as grouped rows.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Owner-only options are hidden from attendants; the router and the
    // database refuse them as well.
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));

    final groups = [
      _MoreGroup(
        title: 'People & Transactions',
        items: [
          _MoreItem(
            title: 'Customers',
            subtitle: 'Customer profiles and credit balances',
            icon: Icons.people_alt_outlined,
            onTap: () => context.push('/customers'),
          ),
          _MoreItem(
            title: 'Purchases',
            subtitle: 'Stock bought from suppliers',
            icon: Icons.shopping_bag_outlined,
            onTap: () => context.push('/purchases'),
          ),
          _MoreItem(
            title: 'Suppliers',
            subtitle: 'Supplier contacts and details',
            icon: Icons.local_shipping_outlined,
            onTap: () => context.push('/suppliers'),
          ),
          if (isOwner)
            _MoreItem(
              title: 'Expenses',
              subtitle: 'Rent, utilities and other operating costs',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => context.push('/expenses'),
            ),
        ],
      ),
      if (isOwner)
        _MoreGroup(
          title: 'Business & Insights',
          items: [
            _MoreItem(
              title: 'Business Performance',
              subtitle: 'Sales, costs, expenses and profit',
              icon: Icons.insights_outlined,
              onTap: () => context.push('/reports/business-performance'),
            ),
            _MoreItem(
              title: 'Inventory Report',
              subtitle: 'Stock position and inventory value',
              icon: Icons.inventory_2_outlined,
              onTap: () => context.push('/reports/inventory'),
            ),
            _MoreItem(
              title: 'Analytics',
              subtitle: 'Sales trends and customer activity',
              icon: Icons.analytics_outlined,
              comingSoon: true,
              onTap: () => _showComingSoon(context, 'Analytics'),
            ),
          ],
        ),
      _MoreGroup(
        title: 'App & Administration',
        items: [
          if (isOwner) ...[
            _MoreItem(
              title: 'Settings',
              subtitle: 'Shop profile, logo and categories',
              icon: Icons.settings_outlined,
              onTap: () => context.push('/settings'),
            ),
            _MoreItem(
              title: 'Users & Permissions',
              subtitle: 'Shop attendants and their access',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => context.push('/users'),
            ),
          ],
          _MoreItem(
            title: 'Notifications',
            subtitle: 'Alerts and shop notifications',
            icon: Icons.notifications_none_rounded,
            comingSoon: true,
            onTap: () => _showComingSoon(context, 'Notifications'),
          ),
          _MoreItem(
            title: 'Help & Support',
            subtitle: 'Get help using ShopMate',
            icon: Icons.help_outline_rounded,
            comingSoon: true,
            onTap: () => _showComingSoon(context, 'Help & Support'),
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = Breakpoints.pagePadding(
              constraints.maxWidth,
              maxWidth: ContentWidth.standard,
            );
            final isCompact = Breakpoints.of(constraints.maxWidth).isCompact;
            // Two columns of groups once there is room for them.
            final columns = constraints.maxWidth >= Breakpoints.expanded
                ? 2
                : 1;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isCompact ? AppSpacing.md : AppSpacing.xxl,
                horizontal,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeader(
                    title: 'More',
                    subtitle: 'Records, reports and shop administration',
                    showMenuButton: true,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (columns == 1)
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.xxl),
                      groups[i],
                    ]
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var c = 0; c < columns; c++) ...[
                          if (c > 0) const SizedBox(width: AppSpacing.xxl),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var i = c;
                                  i < groups.length;
                                  i += columns
                                ) ...[
                                  if (i >= columns)
                                    const SizedBox(height: AppSpacing.xxl),
                                  groups[i],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// A titled group of rows in one bordered section.
class _MoreGroup extends StatelessWidget {
  const _MoreGroup({required this.title, required this.items});

  final String title;
  final List<_MoreItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const RowDivider(indent: 64),
                items[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: title,
      details: [subtitle],
      leading: IconTile(
        icon: icon,
        color: comingSoon ? AppColors.textMuted : AppColors.primary,
        background: comingSoon ? AppColors.surfaceMuted : null,
      ),
      trailing: comingSoon
          ? const StatusBadge(
              label: 'Soon',
              tone: StatusTone.neutral,
              showDot: false,
            )
          : null,
      showChevron: !comingSoon,
      onTap: onTap,
    );
  }
}
