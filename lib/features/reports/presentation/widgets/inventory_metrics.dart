import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/inventory_report.dart';

/// Formats a whole number with thousands separators, e.g. `12345` -> `12,345`.
String _formatCount(int value) {
  final sign = value < 0 ? '-' : '';
  final grouped = value.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  return '$sign$grouped';
}

String _plural(int count, String singular, String plural) {
  return '${_formatCount(count)} ${count == 1 ? singular : plural}';
}

/// Lays tiles out in [columns] equal columns; a tile with `fullWidth` spans
/// the whole row.
class _TileWrap extends StatelessWidget {
  const _TileWrap({required this.columnsFor, required this.tiles});

  final int Function(double width) columnsFor;
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = columnsFor(width);
        final tileWidth = (width - AppSpacing.md * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final tile in tiles)
              SizedBox(width: tile.spansRow ? width : tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// What the stock is worth: cost value, selling value and the expected
/// gross profit returned by the database.
class InventoryValuationCards extends StatelessWidget {
  const InventoryValuationCards({super.key, required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    final profit = report.expectedGrossProfit;
    final profitTone = profit < 0
        ? _Tone.alert
        : profit > 0
        ? _Tone.positive
        : _Tone.neutral;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across on wide layouts; on tablets the profit card spans
        // the row beneath the two value cards.
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;

        return _TileWrap(
          columnsFor: (_) => columns,
          tiles: [
            _Tile(
              label: 'Inventory Cost Value',
              value: formatGhs(report.inventoryCostValue),
              caption: 'Stock on hand at current cost prices',
              icon: Icons.inventory_2_outlined,
              emphasized: true,
            ),
            _Tile(
              label: 'Potential Selling Value',
              value: formatGhs(report.potentialSellingValue),
              caption: 'Stock on hand at current selling prices',
              icon: Icons.sell_outlined,
              emphasized: true,
            ),
            _Tile(
              label: 'Expected Gross Profit',
              value: formatGhs(profit),
              caption: 'Selling value minus cost value',
              icon: switch (profitTone) {
                _Tone.alert => Icons.trending_down_rounded,
                _Tone.positive => Icons.trending_up_rounded,
                _ => Icons.trending_flat_rounded,
              },
              tone: profitTone,
              badge: switch (profitTone) {
                _Tone.alert => 'Loss',
                _Tone.positive => 'Profit',
                _ => 'Break-even',
              },
              emphasized: true,
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

    return _TileWrap(
      columnsFor: (width) => width >= 900
          ? 4
          : width >= 560
          ? 2
          : 1,
      tiles: [
        _Tile(
          label: 'Products',
          value: _formatCount(report.totalProducts),
          caption: 'Active products, including out of stock',
          icon: Icons.category_outlined,
        ),
        _Tile(
          label: 'Units in Stock',
          value: _formatCount(report.totalUnits),
          caption: 'Units currently on hand',
          icon: Icons.inventory_outlined,
        ),
        _Tile(
          label: 'Low Stock',
          value: _formatCount(low),
          caption: low == 0
              ? 'No products at or below their alert level'
              : '${_plural(low, 'product', 'products')} at or below '
                    'their alert level',
          icon: Icons.warning_amber_rounded,
          tone: low > 0 ? _Tone.warning : _Tone.neutral,
        ),
        _Tile(
          label: 'Out of Stock',
          value: _formatCount(out),
          caption: out == 0
              ? 'Every active product has stock'
              : '${_plural(out, 'product', 'products')} with no units left',
          icon: Icons.remove_shopping_cart_outlined,
          tone: out > 0 ? _Tone.alert : _Tone.neutral,
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
    return _TileWrap(
      columnsFor: (width) => width >= 560 ? 2 : 1,
      tiles: [
        _Tile(
          label: 'Units Purchased',
          value: _formatCount(report.unitsPurchased),
          caption: 'All completed purchases',
          icon: Icons.local_shipping_outlined,
        ),
        _Tile(
          label: 'Units Sold',
          value: _formatCount(report.unitsSold),
          caption: 'All sales, including credit sales',
          icon: Icons.point_of_sale_outlined,
        ),
      ],
    );
  }
}

enum _Tone { neutral, positive, warning, alert }

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.tone = _Tone.neutral,
    this.badge,
    this.emphasized = false,
    this.spansRow = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final _Tone tone;

  /// Short status text, so tone is never conveyed by color alone.
  final String? badge;

  /// Valuation figures use the larger headline size.
  final bool emphasized;
  final bool spansRow;

  Color get _toneColor => switch (tone) {
    _Tone.positive => AppColors.success,
    _Tone.warning => AppColors.warning,
    _Tone.alert => AppColors.error,
    _Tone.neutral => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasized
        ? AppTypography.textTheme.headlineSmall!
        : AppTypography.textTheme.titleLarge!;
    final badge = this.badge;

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
              const SizedBox(width: AppSpacing.sm),
              Icon(icon, size: 18, color: _toneColor),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: valueStyle.copyWith(
              color: switch (tone) {
                _Tone.warning => AppColors.warning,
                _Tone.alert => AppColors.error,
                _ => AppColors.textPrimary,
              },
              fontWeight: FontWeight.w800,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: _toneColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge,
                style: AppTypography.textTheme.bodySmall!.copyWith(
                  color: _toneColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
