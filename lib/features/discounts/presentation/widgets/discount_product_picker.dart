import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../../products/domain/entities/product.dart';

/// Chooses the products a 'selected products' discount applies to, from the
/// shop's already-loaded active products (searching never refetches).
class DiscountProductPicker extends StatefulWidget {
  const DiscountProductPicker({
    super.key,
    required this.products,
    required this.selectedIds,
    required this.onChanged,
    required this.enabled,
  });

  final List<Product> products;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  /// Rows are built lazily inside this height, so long catalogues stay fast.
  static const double listHeight = 360;

  @override
  State<DiscountProductPicker> createState() => _DiscountProductPickerState();
}

class _DiscountProductPickerState extends State<DiscountProductPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Product product) {
    if (_query.isEmpty) return true;
    return product.name.toLowerCase().contains(_query) ||
        (product.sku?.toLowerCase().contains(_query) ?? false) ||
        (product.barcode?.toLowerCase().contains(_query) ?? false);
  }

  void _toggle(Product product, bool selected) {
    final next = {...widget.selectedIds};
    if (selected) {
      next.add(product.id);
    } else {
      next.remove(product.id);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final products = [...widget.products]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final visible = products.where(_matches).toList();
    final activeIds = {for (final product in products) product.id};
    final selectedActive = widget.selectedIds.where(activeIds.contains).length;
    final unavailable = widget.selectedIds.length - selectedActive;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$selectedActive of ${products.length} products selected',
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.selectedIds.isNotEmpty)
                TextButton(
                  onPressed: widget.enabled
                      ? () => widget.onChanged(<String>{})
                      : null,
                  child: const Text('Clear selection'),
                ),
            ],
          ),
          if (unavailable > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$unavailable selected '
                    '${unavailable == 1 ? 'product is' : 'products are'} no '
                    'longer active and will not be discounted.',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.enabled
                      ? () => widget.onChanged(
                          widget.selectedIds.where(activeIds.contains).toSet(),
                        )
                      : null,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppSearchField(
            controller: _searchController,
            hintText: 'Search products by name, SKU or barcode',
            onChanged: (value) {
              setState(() => _query = value.trim().toLowerCase());
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: DiscountProductPicker.listHeight,
            child: products.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.inventory_2_outlined,
                    title: 'No active products',
                    message: 'Add products before choosing them here.',
                  )
                : visible.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: 'No matching products',
                    message: 'Nothing matches "${_searchController.text}".',
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final product = visible[index];
                      final selected = widget.selectedIds.contains(product.id);
                      return CheckboxListTile(
                        key: ValueKey('discount-product-${product.id}'),
                        value: selected,
                        onChanged: widget.enabled
                            ? (value) => _toggle(product, value ?? false)
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(formatGhs(product.sellingPrice)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
