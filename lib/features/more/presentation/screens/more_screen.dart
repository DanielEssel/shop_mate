import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'More',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              padding: EdgeInsets.all(
                isDesktop ? AppSpacing.xl : AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PageHeader(isDesktop: isDesktop),

                      const SizedBox(height: AppSpacing.xl),

                      _SectionTitle(
                        title: 'People & Transactions',
                        subtitle:
                            'Manage customers, purchases and other business records.',
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _FeatureGrid(
                        isDesktop: isDesktop,
                        items: [
                          _MoreItem(
                            title: 'Customers',
                            subtitle:
                                'Manage customer profiles and purchase relationships.',
                            icon: Icons.people_alt_outlined,
                            onTap: () {
                              context.push('/customers');
                            },
                          ),
                          _MoreItem(
                            title: 'Purchases',
                            subtitle:
                                'Record stock purchases and manage supplier transactions.',
                            icon: Icons.shopping_bag_outlined,
                            onTap: () {
                              context.push('/purchases');
                            },
                          ),
                          _MoreItem(
                            title: 'Suppliers',
                            subtitle:
                                'Manage suppliers and supplier information.',
                            icon: Icons.local_shipping_outlined,
                            onTap: () {
                              _showComingSoon(context, 'Suppliers');
                            },
                          ),
                          _MoreItem(
                            title: 'Expenses',
                            subtitle:
                                'Track shop expenses and operating costs.',
                            icon: Icons.account_balance_wallet_outlined,
                            onTap: () {
                              _showComingSoon(context, 'Expenses');
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      _SectionTitle(
                        title: 'Business & Insights',
                        subtitle: 'Understand how your shop is performing.',
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _FeatureGrid(
                        isDesktop: isDesktop,
                        items: [
                          _MoreItem(
                            title: 'Reports',
                            subtitle:
                                'View sales, inventory and business performance reports.',
                            icon: Icons.bar_chart_outlined,
                            onTap: () {
                              _showComingSoon(context, 'Reports');
                            },
                          ),
                          _MoreItem(
                            title: 'Analytics',
                            subtitle:
                                'Understand sales trends, profit and customer activity.',
                            icon: Icons.analytics_outlined,
                            onTap: () {
                              _showComingSoon(context, 'Analytics');
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      _SectionTitle(
                        title: 'App & Administration',
                        subtitle: 'Configure ShopMate and manage your shop.',
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _FeatureGrid(
                        isDesktop: isDesktop,
                        items: [
                          _MoreItem(
                            title: 'Settings',
                            subtitle:
                                'Configure shop details, preferences and system options.',
                            icon: Icons.settings_outlined,
                            onTap: () {
                              _showComingSoon(context, 'Settings');
                            },
                          ),
                          _MoreItem(
                            title: 'Users & Permissions',
                            subtitle:
                                'Manage staff accounts and access permissions.',
                            icon: Icons.admin_panel_settings_outlined,
                            onTap: () {
                              _showComingSoon(context, 'Users & Permissions');
                            },
                          ),
                          _MoreItem(
                            title: 'Notifications',
                            subtitle:
                                'Manage alerts and important shop notifications.',
                            icon: Icons.notifications_none_rounded,
                            onTap: () {
                              _showComingSoon(context, 'Notifications');
                            },
                          ),
                          _MoreItem(
                            title: 'Help & Support',
                            subtitle:
                                'Get help using ShopMate and understand its features.',
                            icon: Icons.help_outline_rounded,
                            onTap: () {
                              _showComingSoon(context, 'Help & Support');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.apps_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShopMate tools',
                  style: AppTypography.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Access customers, purchases, reports, settings and other shop management tools.',
                  style: AppTypography.textTheme.bodyMedium!.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.textTheme.bodySmall!.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items, required this.isDesktop});

  final List<_MoreItem> items;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 150,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemBuilder: (context, index) {
        return items[index];
      },
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.textTheme.bodySmall!.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
