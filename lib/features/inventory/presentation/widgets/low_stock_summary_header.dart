import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class LowStockSummaryHeader extends StatelessWidget {
  const LowStockSummaryHeader({
    super.key,
    required this.totalItems,
    required this.outOfStockItems,
  });

  final int totalItems;
  final int outOfStockItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasOutOfStock = outOfStockItems > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: hasOutOfStock
            ? AppColors.errorLight
            : AppColors.warningLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasOutOfStock
              ? AppColors.error.withValues(alpha: 0.18)
              : AppColors.warning.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: hasOutOfStock
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasOutOfStock
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              color: hasOutOfStock
                  ? AppColors.error
                  : AppColors.warning,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasOutOfStock
                      ? 'Stock requires immediate attention'
                      : 'Some products are running low',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasOutOfStock
                      ? '$outOfStockItems ${outOfStockItems == 1 ? 'product is' : 'products are'} out of stock.'
                      : '$totalItems ${totalItems == 1 ? 'product is' : 'products are'} below their stock threshold.',
                  style: theme.textTheme.bodyMedium?.copyWith(
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