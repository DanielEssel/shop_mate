import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';
import 'package:go_router/go_router.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({
    required this.productId,
    super.key,
  });

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(
      productByIdProvider(productId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: productAsync.when(
        loading: () => const _LoadingView(),
        error: (error, stackTrace) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Product Details'),
            ),
            body: _ErrorView(
              onRetry: () {
                ref.invalidate(
                  productByIdProvider(productId),
                );
              },
            ),
          );
        },
        data: (product) {
          return _ProductDetailsLoaded(
            product: product,
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN CONTENT
// -----------------------------------------------------------------------------

class _ProductDetailsContent extends StatelessWidget {
  const _ProductDetailsContent({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductHero(product: product),

              const SizedBox(height: AppSpacing.xl),

              _ResponsiveSection(
                title: 'Pricing',
                icon: Icons.payments_outlined,
                children: [
                  _InfoItem(
                    label: 'Selling Price',
                    value: 'GH₵ ${product.sellingPrice.toStringAsFixed(2)}',
                  ),
                  _InfoItem(
                    label: 'Cost Price',
                    value: 'GH₵ ${product.costPrice.toStringAsFixed(2)}',
                  ),
                  _InfoItem(
                    label: 'Profit / Unit',
                    value: 'GH₵ ${product.profitPerUnit.toStringAsFixed(2)}',
                  ),
                  _InfoItem(
                    label: 'Profit Margin',
                    value: '${product.profitMargin.toStringAsFixed(1)}%',
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              _ResponsiveSection(
                title: 'Inventory',
                icon: Icons.inventory_2_outlined,
                children: [
                  _InfoItem(
                    label: 'Current Stock',
                    value: '${product.stockQuantity}',
                  ),
                  _InfoItem(
                    label: 'Low Stock Level',
                    value: '${product.lowStockThreshold}',
                  ),
                  _InfoItem(label: 'Status', value: _stockStatus(product)),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              _SectionCard(
                title: 'Product Information',
                icon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    _DetailRow(label: 'Category', value: product.category),
                    _DetailRow(
                      label: 'SKU',
                      value: product.sku?.isNotEmpty == true
                          ? product.sku!
                          : 'Not assigned',
                    ),
                    _DetailRow(
                      label: 'Barcode',
                      value: product.barcode?.isNotEmpty == true
                          ? product.barcode!
                          : 'Not assigned',
                    ),
                    if (product.description?.isNotEmpty == true)
                      _DetailRow(
                        label: 'Description',
                        value: product.description!,
                      ),
                    _DetailRow(label: 'Product ID', value: product.id),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              _ProductActions(product: product),
            ],
          ),
        ),
      ),
    );
  }

  String _stockStatus(Product product) {
    if (product.isOutOfStock) {
      return 'Out of stock';
    }

    if (product.isLowStock) {
      return 'Low stock';
    }

    return 'In stock';
  }
}

class _ProductDetailsLoaded extends ConsumerWidget {
  const _ProductDetailsLoaded({
    required this.product,
  });

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            tooltip: 'Edit product',
            onPressed: () async {
              final updated = await context.push<bool>(
                '/products/edit',
                extra: product,
              );

              if (updated == true && context.mounted) {
                ref.invalidate(
                  productByIdProvider(product.id),
                );

                ref.invalidate(
                  productsProvider,
                );

                ref.invalidate(
                  lowStockProductsProvider,
                );
              }
            },
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _ProductDetailsContent(
        product: product,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PRODUCT HERO
// -----------------------------------------------------------------------------

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImage(product: product, size: 96),
                const SizedBox(height: AppSpacing.lg),
                _ProductHeroText(product: product),
              ],
            );
          }

          return Row(
            children: [
              _ProductImage(product: product, size: 96),
              const SizedBox(width: AppSpacing.xl),
              Expanded(child: _ProductHeroText(product: product)),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HERO TEXT
// -----------------------------------------------------------------------------

class _ProductHeroText extends StatelessWidget {
  const _ProductHeroText({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          product.category,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (product.sku?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(
            'SKU: ${product.sku}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _StockBadge(product: product),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// PRODUCT IMAGE
// -----------------------------------------------------------------------------

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: imageUrl != null && imageUrl.trim().isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.inventory_2_rounded,
                  size: 42,
                  color: AppColors.primary,
                );
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            )
          : const Icon(
              Icons.inventory_2_rounded,
              size: 42,
              color: AppColors.primary,
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// STOCK BADGE
// -----------------------------------------------------------------------------

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (product.isOutOfStock) {
      color = AppColors.error;
      label = 'Out of stock';
    } else if (product.isLowStock) {
      color = AppColors.warning;
      label = 'Low stock';
    } else {
      color = AppColors.success;
      label = 'In stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RESPONSIVE SECTION
// -----------------------------------------------------------------------------

class _ResponsiveSection extends StatelessWidget {
  const _ResponsiveSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    const SizedBox(height: AppSpacing.lg),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == children.length - 1 ? 0 : AppSpacing.lg,
                    ),
                    child: children[i],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION CARD
// -----------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// INFO ITEM
// -----------------------------------------------------------------------------

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// DETAIL ROW
// -----------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ACTIONS
// -----------------------------------------------------------------------------

class _ProductActions extends ConsumerWidget {
  const _ProductActions({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final updated = await context.push<bool>(
                    '/products/edit',
                    extra: product,
                  );

                  if (updated == true && context.mounted) {
                    ref.invalidate(productByIdProvider(product.id));

                    ref.invalidate(productsProvider);

                    ref.invalidate(lowStockProductsProvider);
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Product'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final updated = await context.push<bool>(
                    '/inventory/adjust',
                    extra: product,
                  );

                  if (updated == true && context.mounted) {
                    ref.invalidate(productByIdProvider(product.id));

                    ref.invalidate(productsProvider);

                    ref.invalidate(lowStockProductsProvider);
                  }
                },
                icon: const Icon(Icons.swap_vert_rounded),
                label: const Text('Adjust Stock'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _showDeleteDialog(context, ref, product);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete Product'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete product?'),
          content: Text(
            'Are you sure you want to delete '
            '"${product.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(deleteProductProvider).call(product.id);

      ref.invalidate(productsProvider);

      ref.invalidate(productByIdProvider(product.id));

      ref.invalidate(lowStockProductsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
      );

      context.pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }
}

// -----------------------------------------------------------------------------
// LOADING
// -----------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// -----------------------------------------------------------------------------
// ERROR
// -----------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load product',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
