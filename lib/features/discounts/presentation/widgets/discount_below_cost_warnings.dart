import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/discount_pricing.dart';
import '../../domain/entities/discount_scope.dart';

/// Products the discount would take below cost. Shows cost, so it is only
/// ever built on the owner's screen.
class DiscountBelowCostWarnings extends StatelessWidget {
  const DiscountBelowCostWarnings({
    super.key,
    required this.products,
    required this.scope,
  });

  final List<BelowCostProduct> products;
  final DiscountScope scope;

  static const _visibleLimit = 8;

  @override
  Widget build(BuildContext context) {
    final blocking = scope == DiscountScope.selectedProducts;
    final color = blocking ? AppColors.danger : AppColors.warning;
    final background = blocking
        ? AppColors.dangerLight
        : AppColors.warningLight;
    final count = products.length;
    final noun = count == 1 ? 'product' : 'products';
    final title = blocking
        ? '$count selected $noun would sell below cost'
        : '$count $noun would sell below cost';
    final message = blocking
        ? 'Remove or reprice ${count == 1 ? 'it' : 'them'} before saving. '
              'A sale that includes ${count == 1 ? 'it' : 'one of them'} '
              'would be refused while this discount is on.'
        : '${count == 1 ? 'It keeps' : 'They keep'} '
              'their normal price and get no discount. Every other product '
              'is discounted.';
    final visible = products.take(_visibleLimit).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  blocking ? Icons.block_rounded : Icons.warning_amber_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in visible) _BelowCostRow(item: item),
          if (count > visible.length)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'and ${count - visible.length} more',
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BelowCostRow extends StatelessWidget {
  const _BelowCostRow({required this.item});

  final BelowCostProduct item;

  static String _money(int cents) => formatGhs(cents / 100);

  @override
  Widget build(BuildContext context) {
    final price = item.price;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.product.name,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${_money(price.originalCents)} → ${_money(price.finalCents)} · '
            'Cost ${_money(price.costCents)} · '
            '${_money(price.shortfallCents)} below cost',
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
