import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/dashboard_summary.dart';

/// Stock position from the dashboard summary's product counts: overall
/// status, the in-stock / low / out split, and a way to act on it.
class DashboardInventoryHealth extends StatelessWidget {
  const DashboardInventoryHealth({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final total = summary.totalProducts;
    final low = summary.lowStockProducts;
    final out = summary.outOfStockProducts;
    final inStock = (total - low - out).clamp(0, total);

    final StatusTone tone;
    final String status;
    final String headline;
    final String message;
    if (out > 0) {
      tone = StatusTone.danger;
      status = 'Critical';
      headline = 'Stock needs attention';
      message = _attentionMessage(low: low, out: out);
    } else if (low > 0) {
      tone = StatusTone.warning;
      status = 'Attention';
      headline = 'Low stock alert';
      message = _attentionMessage(low: low, out: out);
    } else {
      tone = StatusTone.success;
      status = 'Healthy';
      headline = 'Inventory looks good';
      message = total == 0
          ? 'Add products to start tracking stock.'
          : 'All products are currently well stocked.';
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inventory health',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusBadge(label: status, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            headline,
            style: textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            _StockBar(inStock: inStock, low: low, out: out),
          ],
          const SizedBox(height: AppSpacing.lg),
          _CountRow(
            color: AppColors.success,
            label: 'In stock',
            value: inStock,
          ),
          const RowDivider(),
          _CountRow(color: AppColors.warning, label: 'Low stock', value: low),
          const RowDivider(),
          _CountRow(color: AppColors.danger, label: 'Out of stock', value: out),
          const RowDivider(),
          _CountRow(
            color: AppColors.textMuted,
            label: 'Total products',
            value: total,
            emphasize: true,
          ),
          if (low > 0 || out > 0) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/inventory/low-stock'),
                icon: const Icon(Icons.inventory_outlined, size: 18),
                label: const Text('Review low stock'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _attentionMessage({required int low, required int out}) {
    final parts = [
      if (out > 0) '$out out of stock',
      if (low > 0) '$low low stock',
    ];
    return '${parts.join(' · ')}. Restock to avoid missed sales.';
  }
}

/// Proportions of in-stock, low and out-of-stock products.
class _StockBar extends StatelessWidget {
  const _StockBar({
    required this.inStock,
    required this.low,
    required this.out,
  });

  final int inStock;
  final int low;
  final int out;

  @override
  Widget build(BuildContext context) {
    final segments = [
      (inStock, AppColors.success),
      (low, AppColors.warning),
      (out, AppColors.danger),
    ].where((segment) => segment.$1 > 0).toList();

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: segments[i].$1,
                  child: ColoredBox(color: segments[i].$2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.color,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final Color color;
  final String label;
  final int value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          if (!emphasize) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: emphasize
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: emphasize ? FontWeight.w500 : null,
              ),
            ),
          ),
          Text(
            '$value',
            style: AppTypography.amount.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
