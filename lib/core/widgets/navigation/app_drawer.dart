import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_shadows.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Drawer(
      backgroundColor: AppColors.surface,
      width: 310,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(email: user?.email),

            const SizedBox(height: AppSpacing.sm),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  const _DrawerSectionLabel(title: 'MAIN'),

                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    onTap: () => _navigate(context, '/dashboard'),
                  ),

                  _DrawerItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Products',
                    onTap: () => _navigate(context, '/products'),
                  ),

                  _DrawerItem(
                    icon: Icons.warehouse_outlined,
                    title: 'Inventory',
                    onTap: () => _navigate(context, '/inventory'),
                  ),

                  _DrawerItem(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Sales',
                    onTap: () => _navigate(context, '/sales'),
                  ),

                  _DrawerItem(
                    icon: Icons.people_alt_outlined,
                    title: 'Customers',
                    onTap: () => _navigate(context, '/customers'),
                  ),

                  _DrawerItem(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Purchases',
                    onTap: () => _navigate(context, '/purchases'),
                  ),

                  const _DrawerDivider(),

                  const _DrawerSectionLabel(title: 'BUSINESS'),

                  _DrawerItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Suppliers',
                    onTap: () => _showComingSoon(context, 'Suppliers'),
                  ),

                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Expenses',
                    onTap: () => _showComingSoon(context, 'Expenses'),
                  ),

                  _DrawerItem(
                    icon: Icons.bar_chart_outlined,
                    title: 'Reports',
                    onTap: () => _showComingSoon(context, 'Reports'),
                  ),

                  _DrawerItem(
                    icon: Icons.analytics_outlined,
                    title: 'Analytics',
                    onTap: () => _showComingSoon(context, 'Analytics'),
                  ),

                  const _DrawerDivider(),

                  const _DrawerSectionLabel(title: 'SYSTEM'),

                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => _showComingSoon(context, 'Settings'),
                  ),

                  _DrawerItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Users & Permissions',
                    onTap: () =>
                        _showComingSoon(context, 'Users & Permissions'),
                  ),

                  _DrawerItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () => _showComingSoon(context, 'Notifications'),
                  ),

                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () => _showComingSoon(context, 'Help & Support'),
                  ),
                ],
              ),
            ),

            const _DrawerDivider(),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                isDestructive: true,
                onTap: () => _confirmSignOut(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop();

    const shellRoutes = {
      '/dashboard',
      '/products',
      '/inventory',
      '/sales',
      '/more',
    };

    if (shellRoutes.contains(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  static void _showComingSoon(BuildContext context, String feature) {
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text('Are you sure you want to sign out of ShopMate?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !context.mounted) {
      return;
    }

    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop();

    context.go('/login');
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
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
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShopMate',
                  style: AppTypography.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email ?? 'Business Management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.bodySmall!.copyWith(
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

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: AppTypography.textTheme.labelSmall!.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: isDestructive ? color : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}
