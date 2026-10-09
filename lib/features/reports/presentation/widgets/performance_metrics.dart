import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/business_performance.dart';
import 'report_counts.dart';

/// Profit, loss or break-even, conveyed by label and icon as well as colour.
enum PerformanceOutcome {
  positive('Profit', Icons.trending_up_rounded, StatusTone.success),
  negative('Loss', Icons.trending_down_rounded, StatusTone.danger),
  neutral('Break-even', Icons.trending_flat_rounded, StatusTone.neutral);

  const PerformanceOutcome(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static PerformanceOutcome of(double value) {
    if (value > 0) return positive;
    if (value < 0) return negative;
    return neutral;
  }

  Widget badge() => StatusBadge(label: label, tone: tone, icon: icon);
}

String _formatPercent(double value) => '${value.toStringAsFixed(2)}%';

/// The headline figures: net profit with its outcome, the margin and the
/// period's sales. Values come straight from the report entity.
class PerformanceKeyFigures extends StatelessWidget {
  const PerformanceKeyFigures({super.key, required this.performance});

  final BusinessPerformance performance;

  @override
  Widget build(BuildContext context) {
    final outcome = PerformanceOutcome.of(performance.netProfit);
    final salesCount = performance.salesCount;

    return MetricGrid(
      cards: [
        MetricCard(
          label: 'Net Profit',
          value: formatGhs(performance.netProfit),
          caption: 'After cost of goods and expenses',
          // The brand card draws icons green; the badge carries the outcome.
          icon: Icons.account_balance_wallet_outlined,
          emphasized: true,
          badge: outcome.badge(),
        ),
        MetricCard(
          label: 'Profit Margin',
          value: _formatPercent(performance.profitMargin),
          caption: performance.totalSales == 0
              ? 'No sales in this period'
              : 'Net profit as a share of sales',
          icon: Icons.percent_rounded,
          tone: StatusTone.info,
        ),
        MetricCard(
          label: 'Total Sales',
          value: formatGhs(performance.totalSales),
          caption: pluralReportCount(salesCount, 'sale', 'sales'),
          icon: Icons.payments_outlined,
          tone: StatusTone.brand,
        ),
      ],
    );
  }
}

/// The figures in statement order, from sales down to net profit, each with
/// what it covers. Every amount is a stored figure, not recalculated.
class ProfitAndLossStatement extends StatelessWidget {
  const ProfitAndLossStatement({super.key, required this.performance});

  final BusinessPerformance performance;

  @override
  Widget build(BuildContext context) {
    final salesCount = performance.salesCount;
    final expenseCount = performance.expenseCount;
    final gross = PerformanceOutcome.of(performance.grossProfit);
    final net = PerformanceOutcome.of(performance.netProfit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Profit & Loss',
          subtitle: 'How the period’s sales became net profit',
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatementLine(
                label: 'Total Sales',
                caption: pluralReportCount(salesCount, 'sale', 'sales'),
                value: formatGhs(performance.totalSales),
              ),
              const RowDivider(),
              _StatementLine(
                label: 'Cost of Goods Sold',
                caption: 'Recorded cost of items sold',
                value: formatGhs(performance.totalCogs),
                subtract: true,
              ),
              const RowDivider(),
              _StatementLine(
                label: 'Gross Profit',
                caption: 'Sales minus cost of goods sold',
                value: formatGhs(performance.grossProfit),
                outcome: gross,
                subtotal: true,
              ),
              const RowDivider(),
              _StatementLine(
                label: 'Operating Expenses',
                caption: pluralReportCount(expenseCount, 'expense', 'expenses'),
                value: formatGhs(performance.totalExpenses),
                subtract: true,
              ),
              const RowDivider(),
              _StatementLine(
                label: 'Net Profit',
                caption: net.label,
                value: formatGhs(performance.netProfit),
                outcome: net,
                subtotal: true,
                total: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatementLine extends StatelessWidget {
  const _StatementLine({
    required this.label,
    required this.caption,
    required this.value,
    this.subtract = false,
    this.outcome,
    this.subtotal = false,
    this.total = false,
  });

  final String label;
  final String caption;
  final String value;

  /// Lines that are taken away show a minus before the label (an icon:
  /// the minus character is missing from the app font).
  final bool subtract;

  /// For lines that can be a loss: a non-positive result shows its icon.
  final PerformanceOutcome? outcome;
  final bool subtotal;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final outcome = this.outcome;
    final isLoss = outcome == PerformanceOutcome.negative;

    final marker = SizedBox(
      width: 20,
      child: subtract
          ? const Icon(
              Icons.remove_rounded,
              size: 16,
              color: AppColors.textSecondary,
              semanticLabel: 'less',
            )
          : null,
    );
    final labelText = Text(
      label,
      style: (subtotal ? textTheme.titleSmall : textTheme.bodyMedium)?.copyWith(
        color: AppColors.textPrimary,
      ),
    );
    final captionText = Text(
      caption,
      style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
    );

    final showOutcome =
        outcome != null && outcome != PerformanceOutcome.positive;
    const outcomeWidth = 18 + AppSpacing.xs;

    // [maxWidth] is the room for the whole amount, outcome icon included.
    Widget amount(double maxWidth) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (outcome != null && showOutcome) ...[
          Tooltip(
            message: outcome.label,
            child: Icon(outcome.icon, size: 18, color: outcome.tone.foreground),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        // Right-aligned; shrinks rather than overflows.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: showOutcome ? maxWidth - outcomeWidth : maxWidth,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: (total ? AppTypography.metricMedium : AppTypography.amount)
                  .copyWith(
                    color: isLoss ? AppColors.danger : AppColors.textPrimary,
                  ),
            ),
          ),
        ),
      ],
    );

    return Container(
      color: total ? AppColors.surfaceSubtle : null,
      padding: EdgeInsets.symmetric(
        // Narrow phones need the room for the label and amount.
        horizontal: MediaQuery.sizeOf(context).width < 360
            ? AppSpacing.lg
            : AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          // Narrow: the label takes the whole first line, so names like
          // "Cost of Goods Sold" are not squeezed beside the amount; the
          // caption and then the right-aligned amount follow beneath.
          if (width < _stackBelow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    marker,
                    Expanded(child: labelText),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: captionText,
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: amount(width - 20),
                ),
              ],
            );
          }

          return Row(
            children: [
              marker,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 2), captionText],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              amount(width * 0.5),
            ],
          );
        },
      ),
    );
  }

  /// Row widths below this stack the label above the amount.
  static const double _stackBelow = 340;
}
