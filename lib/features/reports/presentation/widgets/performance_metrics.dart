import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/business_performance.dart';

/// Profit, loss or break-even, conveyed by label and icon as well as color.
enum _Outcome {
  positive('Profit', Icons.trending_up_rounded, AppColors.success),
  negative('Loss', Icons.trending_down_rounded, AppColors.error),
  neutral('Break-even', Icons.trending_flat_rounded, AppColors.textSecondary);

  const _Outcome(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static _Outcome of(double value) {
    if (value > 0) return positive;
    if (value < 0) return negative;
    return neutral;
  }
}

String _formatPercent(double value) => '${value.toStringAsFixed(2)}%';

/// The headline result: net profit with its margin.
class NetProfitCard extends StatelessWidget {
  const NetProfitCard({super.key, required this.performance});

  final BusinessPerformance performance;

  @override
  Widget build(BuildContext context) {
    final outcome = _Outcome.of(performance.netProfit);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net Profit',
                style: AppTypography.textTheme.bodyMedium!.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatGhs(performance.netProfit),
                style: AppTypography.textTheme.headlineMedium!.copyWith(
                  color: outcome == _Outcome.negative
                      ? AppColors.error
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _OutcomeBadge(outcome: outcome),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profit Margin',
                style: AppTypography.textTheme.bodySmall!.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatPercent(performance.profitMargin),
                style: AppTypography.textTheme.titleLarge!.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (performance.totalSales == 0)
                Text(
                  'No sales in this period',
                  style: AppTypography.textTheme.bodySmall!.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.outcome});

  final _Outcome outcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: outcome.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(outcome.icon, size: 16, color: outcome.color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            outcome.label,
            style: AppTypography.textTheme.bodySmall!.copyWith(
              color: outcome.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The supporting figures, from sales down to operating expenses.
class PerformanceMetricsGrid extends StatelessWidget {
  const PerformanceMetricsGrid({super.key, required this.performance});

  final BusinessPerformance performance;

  @override
  Widget build(BuildContext context) {
    final salesCount = performance.salesCount;
    final expenseCount = performance.expenseCount;

    final tiles = [
      _MetricTile(
        label: 'Total Sales',
        value: formatGhs(performance.totalSales),
        caption: '$salesCount ${salesCount == 1 ? 'sale' : 'sales'}',
      ),
      _MetricTile(
        label: 'Cost of Goods Sold',
        value: formatGhs(performance.totalCogs),
        caption: 'Recorded cost of items sold',
      ),
      _MetricTile(
        label: 'Gross Profit',
        value: formatGhs(performance.grossProfit),
        outcome: _Outcome.of(performance.grossProfit),
        caption: 'Sales minus cost of goods sold',
      ),
      _MetricTile(
        label: 'Operating Expenses',
        value: formatGhs(performance.totalExpenses),
        caption: '$expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final tileWidth =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.caption,
    this.outcome,
  });

  final String label;
  final String value;
  final String caption;

  /// Shown for figures that can be negative.
  final _Outcome? outcome;

  @override
  Widget build(BuildContext context) {
    final outcome = this.outcome;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.textTheme.bodyMedium!.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (outcome != null && outcome != _Outcome.positive)
                Tooltip(
                  message: outcome.label,
                  child: Icon(outcome.icon, size: 18, color: outcome.color),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.textTheme.titleLarge!.copyWith(
              color: outcome == _Outcome.negative
                  ? AppColors.error
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            style: AppTypography.textTheme.bodySmall!.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
