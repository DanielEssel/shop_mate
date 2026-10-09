import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/inventory_report.dart';
import 'report_counts.dart';

/// A figure and whether it spans its whole row.
typedef _Figure = ({Widget card, bool spansRow});

/// Lays figures out in [columnsFor] equal columns, rows sized to their
/// tallest card; a figure that `spansRow` takes a row of its own.
class _FigureWrap extends StatelessWidget {
  const _FigureWrap({required this.columnsFor, required this.figures});

  final int Function(double width) columnsFor;
  final List<_Figure> figures;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        const spacing = AppSpacing.md;

        // Each row: its cards, and whether it is a full-width figure.
        final rows = <({List<Widget> cards, bool full})>[];
        var current = <Widget>[];
        for (final figure in figures) {
          if (figure.spansRow) {
            if (current.isNotEmpty) rows.add((cards: current, full: false));
            current = [];
            rows.add((cards: [figure.card], full: true));
            continue;
          }
          current.add(figure.card);
          if (current.length == columns) {
            rows.add((cards: current, full: false));
            current = [];
          }
        }
        if (current.isNotEmpty) rows.add((cards: current, full: false));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < rows[i].cards.length; j++) ...[
                      if (j > 0) const SizedBox(width: spacing),
                      Expanded(child: rows[i].cards[j]),
                    ],
                    // Keep a partial row aligned with full ones.
                    if (!rows[i].full)
                      for (var j = rows[i].cards.length; j < columns; j++) ...[
                        const SizedBox(width: spacing),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Profit, loss or break-even as text and icon, not colour alone.
Widget _outcomeBadge(double value) {
  if (value < 0) {
    return const StatusBadge(
      label: 'Loss',
      tone: StatusTone.danger,
      icon: Icons.trending_down_rounded,
    );
  }
  if (value > 0) {
    return const StatusBadge(
      label: 'Profit',
      tone: StatusTone.success,
      icon: Icons.trending_up_rounded,
    );
  }
  return const StatusBadge(
    label: 'Break-even',
    tone: StatusTone.neutral,
    icon: Icons.trending_flat_rounded,
  );
}

/// What the stock is worth: cost value, selling value and the expected
/// gross profit returned by the database.
class InventoryValuationCards extends StatelessWidget {
  const InventoryValuationCards({super.key, required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    final profit = report.expectedGrossProfit;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across on wide layouts; on tablets the profit card spans
        // the row beneath the two value cards; phones stack them so large
        // amounts stay readable.
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;

        return _FigureWrap(
          columnsFor: (_) => columns,
          figures: [
            (
              card: MetricCard(
                label: 'Inventory Cost Value',
                value: formatGhs(report.inventoryCostValue),
                caption: 'Stock on hand at current cost prices',
                icon: Icons.inventory_2_outlined,
                emphasized: true,
              ),
              spansRow: false,
            ),
            (
              card: MetricCard(
                label: 'Potential Selling Value',
                value: formatGhs(report.potentialSellingValue),
                caption: 'Stock on hand at current selling prices',
                icon: Icons.sell_outlined,
                tone: StatusTone.brand,
              ),
              spansRow: false,
            ),
            (
              card: MetricCard(
                label: 'Expected Gross Profit',
                value: formatGhs(profit),
                caption: 'Selling value minus cost value',
                icon: profit < 0
                    ? Icons.trending_down_rounded
                    : profit > 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_flat_rounded,
                tone: profit < 0
                    ? StatusTone.danger
                    : profit > 0
                    ? StatusTone.success
                    : StatusTone.neutral,
                valueColor: profit < 0 ? AppColors.danger : null,
                badge: _outcomeBadge(profit),
              ),
              spansRow: columns == 2,
            ),
          ],
        );
      },
    );
  }
}

/// What is on hand: products, units and stock alerts.
class InventoryStockGrid extends StatelessWidget {
  const InventoryStockGrid({super.key, required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    final low = report.lowStockCount;
    final out = report.outOfStockCount;

    return _FigureWrap(
      columnsFor: (width) => width >= 900
          ? 4
          : width >= 560
          ? 2
          : 1,
      figures: [
        (
          card: MetricCard(
            label: 'Products',
            value: formatReportCount(report.totalProducts),
            caption: 'Active products, including out of stock',
            icon: Icons.category_outlined,
            tone: StatusTone.brand,
          ),
          spansRow: false,
        ),
        (
          card: MetricCard(
            label: 'Units in Stock',
            value: formatReportCount(report.totalUnits),
            caption: 'Units currently on hand',
            icon: Icons.inventory_outlined,
            tone: StatusTone.brand,
          ),
          spansRow: false,
        ),
        (
          card: MetricCard(
            label: 'Low Stock',
            value: formatReportCount(low),
            caption: low == 0
                ? 'No products at or below their alert level'
                : '${pluralReportCount(low, 'product', 'products')} at or below '
                      'their alert level',
            icon: Icons.warning_amber_rounded,
            tone: low > 0 ? StatusTone.warning : StatusTone.neutral,
            captionTone: low > 0 ? StatusTone.warning : null,
            valueColor: low > 0 ? AppColors.warning : null,
          ),
          spansRow: false,
        ),
        (
          card: MetricCard(
            label: 'Out of Stock',
            value: formatReportCount(out),
            caption: out == 0
                ? 'Every active product has stock'
                : '${pluralReportCount(out, 'product', 'products')} with no units left',
            icon: Icons.remove_shopping_cart_outlined,
            tone: out > 0 ? StatusTone.danger : StatusTone.neutral,
            captionTone: out > 0 ? StatusTone.danger : null,
            valueColor: out > 0 ? AppColors.danger : null,
          ),
          spansRow: false,
        ),
      ],
    );
  }
}

/// How much stock has moved in and out over the shop's history.
class InventoryActivityGrid extends StatelessWidget {
  const InventoryActivityGrid({super.key, required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    return _FigureWrap(
      columnsFor: (width) => width >= 560 ? 2 : 1,
      figures: [
        (
          card: MetricCard(
            label: 'Units Purchased',
            value: formatReportCount(report.unitsPurchased),
            caption: 'All completed purchases',
            icon: Icons.local_shipping_outlined,
            tone: StatusTone.info,
          ),
          spansRow: false,
        ),
        (
          card: MetricCard(
            label: 'Units Sold',
            value: formatReportCount(report.unitsSold),
            caption: 'All sales, including credit sales',
            icon: Icons.point_of_sale_outlined,
            tone: StatusTone.info,
          ),
          spansRow: false,
        ),
      ],
    );
  }
}
