import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import 'dashboard_quick_action_card.dart';
import 'dashboard_section_header.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.point_of_sale_rounded,
        title: 'New Sale',
        description: 'Record a sale',
        onTap: () => context.push('/sales/new'),
      ),
      _QuickAction(
        icon: Icons.add_box_rounded,
        title: 'Add Product',
        description: 'Create a product',
        onTap: () => context.push('/products/new'),
      ),
      _QuickAction(
        icon: Icons.inventory_2_rounded,
        title: 'Adjust Stock',
        description: 'Update inventory',
        onTap: () => context.push('/inventory/adjust'),
      ),
      _QuickAction(
        icon: Icons.shopping_bag_rounded,
        title: 'New Purchase',
        description: 'Record a purchase',
        onTap: () => context.push('/purchases/new'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Quick Actions',
          subtitle: 'Common tasks for your shop',
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;

            final spacing = AppSpacing.md;

            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth -
                        (spacing * (columns - 1))) /
                    columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: actions.map((action) {
                return SizedBox(
                  width: width,
                  child: DashboardQuickActionCard(
                    icon: action.icon,
                    title: action.title,
                    description: action.description,
                    onTap: action.onTap,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
}