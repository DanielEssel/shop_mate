import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/dashboard_summary.dart';

class DashboardInventoryAlert extends StatelessWidget {
  const DashboardInventoryAlert({
    super.key,
    required this.summary,
  });

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasOutOfStock = summary.outOfStockProducts > 0;
    final hasLowStock = summary.lowStockProducts > 0;

    if (!hasOutOfStock && !hasLowStock) {
      return const _InventoryHealthy();
    }

    final isCritical = hasOutOfStock;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/inventory'),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isCritical
                ? AppColors.errorLight
                : AppColors.warningLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCritical
                  ? AppColors.error.withValues(alpha: 0.18)
                  : AppColors.warning.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isCritical
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isCritical
                      ? Icons.error_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: isCritical
                      ? AppColors.error
                      : AppColors.warning,
                  size: 23,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCritical
                          ? 'Inventory needs attention'
                          : 'Low stock alert',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _message(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _message() {
    final parts = <String>[];

    if (summary.outOfStockProducts > 0) {
      parts.add(
        '${summary.outOfStockProducts} out of stock',
      );
    }

    if (summary.lowStockProducts > 0) {
      parts.add(
        '${summary.lowStockProducts} low stock',
      );
    }

    return '${parts.join(' • ')}. Review your inventory.';
  }
}

class _InventoryHealthy extends StatelessWidget {
  const _InventoryHealthy();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 23,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory looks good',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No products are currently low or out of stock.',
                  style: theme.textTheme.bodySmall?.copyWith(
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