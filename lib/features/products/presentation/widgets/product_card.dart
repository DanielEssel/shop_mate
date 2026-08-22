import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    required this.onTap,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _ProductImage(
                product: product,
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      product.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'GH₵ ${product.sellingPrice.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              _StockIndicator(
                product: product,
              ),

              const SizedBox(width: AppSpacing.sm),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PRODUCT IMAGE
// -----------------------------------------------------------------------------

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.product,
  });

  final Product product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;

    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: imageUrl != null && imageUrl.trim().isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: 56,
              height: 56,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const _ImagePlaceholder();
              },
              loadingBuilder: (
                context,
                child,
                loadingProgress,
              ) {
                if (loadingProgress == null) {
                  return child;
                }

                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            )
          : const _ImagePlaceholder(),
    );
  }
}

// -----------------------------------------------------------------------------
// IMAGE PLACEHOLDER
// -----------------------------------------------------------------------------

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_rounded,
        color: AppColors.primary,
        size: 26,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STOCK INDICATOR
// -----------------------------------------------------------------------------

class _StockIndicator extends StatelessWidget {
  const _StockIndicator({
    required this.product,
  });

  final Product product;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    if (product.isOutOfStock) {
      color = AppColors.error;
      label = 'Out';
    } else if (product.isLowStock) {
      color = AppColors.warning;
      label = '${product.stockQuantity} left';
    } else {
      color = AppColors.success;
      label = '${product.stockQuantity} in stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}