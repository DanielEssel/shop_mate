import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/dashboard_summary.dart';

class DashboardLowStockBanner extends StatelessWidget {
  const DashboardLowStockBanner({
    super.key,
    required this.summary,
  });

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasOutOfStock = summary.outOfStockProducts > 0;
    final hasLowStock = summary.lowStockProducts > 0;

    if (!hasOutOfStock && !hasLowStock) {
      return const _StockHealthyBanner();
    }

    final isCritical = hasOutOfStock;
    final color =
        isCritical ? AppColors.error : AppColors.warning;

    final backgroundColor =
        isCritical
            ? AppColors.errorLight
            : AppColors.warningLight;

    final icon =
        isCritical
            ? Icons.error_outline_rounded
            : Icons.warning_amber_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/inventory/low-stock'),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCritical
                          ? 'Stock needs attention'
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
                      _buildMessage(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: color,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMessage() {
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

    return '${parts.join(' • ')}. Tap to review inventory.';
  }
}

class _StockHealthyBanner extends StatelessWidget {
  const _StockHealthyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.success.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 24,
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory looks good',
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
                  'All products are currently well stocked.',
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
        ],
      ),
    );
  }
}