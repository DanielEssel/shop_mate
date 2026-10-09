import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../utils/money_format.dart';
import 'headers.dart';
import 'surfaces.dart';
import 'transaction.dart';

/// One product line of a recorded transaction, with the stored amounts.
@immutable
class LineItem {
  const LineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  /// The stored line total (never recomputed here).
  final double total;
}

/// The products in a sale or purchase: a Product | Qty | Unit | Total table
/// from about tablet width, compact two-line rows on phones, and the stored
/// transaction total underneath.
class LineItemsSection extends StatelessWidget {
  const LineItemsSection({
    super.key,
    required this.items,
    this.title = 'Items',
    this.unitLabel = 'Unit Price',
    this.totalLabel = 'Total',
    this.total,
    this.emptyMessage = 'No items found.',
  });

  final List<LineItem> items;
  final String title;

  /// Header for the per-unit column, e.g. "Unit Price" or "Unit Cost".
  final String unitLabel;
  final String totalLabel;

  /// The stored transaction total, shown under the lines when given.
  final double? total;
  final String emptyMessage;

  static const double _tableFrom = 560;

  @override
  Widget build(BuildContext context) {
    final count = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final total = this.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          subtitle: items.isEmpty
              ? null
              : '${items.length} ${items.length == 1 ? 'product' : 'products'}'
                    ' · $count ${count == 1 ? 'unit' : 'units'}',
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final table = constraints.maxWidth >= _tableFrom;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (table) _TableHeader(unitLabel: unitLabel),
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0 || table) const RowDivider(),
                          table
                              ? _TableRow(item: items[i])
                              : _CompactRow(item: items[i]),
                        ],
                        if (total != null) ...[
                          const Divider(height: 1, thickness: 1),
                          Container(
                            color: AppColors.surfaceSubtle,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                              vertical: AppSpacing.md,
                            ),
                            child: SummaryLine(
                              label: totalLabel,
                              value: formatGhs(total),
                              emphasized: true,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.unitLabel});

  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {TextAlign align = TextAlign.start}) {
      return Text(
        text.toUpperCase(),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.overline.copyWith(color: AppColors.textMuted),
      );
    }

    return Container(
      color: AppColors.surfaceSubtle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: cell('Product')),
          Expanded(flex: 1, child: cell('Qty', align: TextAlign.end)),
          Expanded(flex: 2, child: cell(unitLabel, align: TextAlign.end)),
          Expanded(flex: 2, child: cell('Total', align: TextAlign.end)),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.item});

  final LineItem item;

  @override
  Widget build(BuildContext context) {
    final muted = AppTypography.amount.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.end,
              style: muted,
            ),
          ),
          Expanded(
            flex: 2,
            child: _Amount(text: formatGhs(item.unitPrice), style: muted),
          ),
          Expanded(
            flex: 2,
            child: _Amount(
              text: formatGhs(item.total),
              style: AppTypography.amount,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phones: name and line total, then "qty × unit price".
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.item});

  final LineItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} × ${formatGhs(item.unitPrice)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(formatGhs(item.total), style: AppTypography.amount),
        ],
      ),
    );
  }
}

/// A right-aligned amount that shrinks rather than overflowing its column.
class _Amount extends StatelessWidget {
  const _Amount({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}
