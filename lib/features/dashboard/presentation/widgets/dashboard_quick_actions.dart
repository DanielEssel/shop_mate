import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';

/// New Sale is the dominant action; the others are compact tiles beside it.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.canAdjustStock});

  /// Stock adjustment is owner-only.
  final bool canAdjustStock;

  @override
  Widget build(BuildContext context) {
    final secondary = [
      QuickAction(
        icon: Icons.add_box_outlined,
        label: 'Add Product',
        stacked: true,
        onTap: () => context.push('/products/new'),
      ),
      QuickAction(
        icon: Icons.shopping_bag_outlined,
        label: 'New Purchase',
        stacked: true,
        onTap: () => context.push('/purchases/new'),
      ),
      if (canAdjustStock)
        QuickAction(
          icon: Icons.tune_rounded,
          label: 'Adjust Stock',
          stacked: true,
          onTap: () => context.push('/inventory/adjust'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: AppSpacing.md),
        QuickAction(
          icon: Icons.point_of_sale_rounded,
          label: 'New Sale',
          description: 'Record a sale and print a receipt',
          primary: true,
          onTap: () => context.push('/sales/new'),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < secondary.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: secondary[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
