import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/product.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_visuals.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));
    // Cost, margin, stock adjustment and deletion are owner-level; attendants
    // see the selling price and can edit basic details.
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontal = Breakpoints.pagePadding(
              width,
              maxWidth: ContentWidth.standard,
            );
            final product = productAsync.value;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    Breakpoints.of(width).isCompact
                        ? AppSpacing.md
                        : AppSpacing.xxl,
                    horizontal,
                    AppSpacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: PageHeader(
                      title: 'Product Details',
                      leading: pageHeaderLeading(context),
                      actions: product == null
                          ? const []
                          : [
                              SecondaryButton(
                                label: 'Edit Product',
                                icon: Icons.edit_outlined,
                                onPressed: () => _edit(context, ref, product),
                              ),
                              if (isOwner)
                                PrimaryButton(
                                  label: 'Adjust Stock',
                                  icon: Icons.swap_vert_rounded,
                                  onPressed: () =>
                                      _adjustStock(context, ref, product),
                                ),
                            ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    0,
                    horizontal,
                    AppSpacing.xxxl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: productAsync.when(
                      loading: () => const _DetailsSkeleton(),
                      error: (error, stackTrace) => SurfaceCard(
                        child: ErrorState(
                          compact: true,
                          title: 'Unable to load product',
                          message: 'Check your connection and try again.',
                          onRetry: () =>
                              ref.invalidate(productByIdProvider(productId)),
                        ),
                      ),
                      data: (product) => _ProductDetailsBody(
                        product: product,
                        isOwner: isOwner,
                        wide: width >= Breakpoints.expanded,
                        onDelete: () => _confirmDelete(context, ref, product),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _refreshProduct(WidgetRef ref, Product product) {
    ref.invalidate(productByIdProvider(product.id));
    ref.invalidate(productsProvider);
    ref.invalidate(lowStockProductsProvider);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final updated = await context.push<bool>('/products/edit', extra: product);

    if (updated == true && context.mounted) {
      _refreshProduct(ref, product);
    }
  }

  Future<void> _adjustStock(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final updated = await context.push<bool>(
      '/inventory/adjust',
      extra: product,
    );

    if (updated == true && context.mounted) {
      _refreshProduct(ref, product);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete product?',
      message: 'Are you sure you want to delete "${product.name}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) {
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
// BODY
// -----------------------------------------------------------------------------

class _ProductDetailsBody extends StatelessWidget {
  const _ProductDetailsBody({
    required this.product,
    required this.isOwner,
    required this.wide,
    required this.onDelete,
  });

  final Product product;
  final bool isOwner;

  /// Desktop: information beside pricing and stock.
  final bool wide;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(product);
    final category = product.categoryName == null
        ? 'No category'
        : product.categoryIsActive
        ? product.categoryName!
        : '${product.categoryName!} (archived)';

    final identity = IdentityPanel(
      visual: _ProductImage(product: product),
      title: product.name,
      subtitle: category,
      badges: [StatusBadge(label: status.label, tone: status.tone)],
    );

    final metrics = MetricGrid(
      cards: [
        MetricCard(
          label: 'Selling Price',
          value: formatGhs(product.sellingPrice),
          caption: 'Per unit',
          icon: Icons.sell_outlined,
          emphasized: true,
        ),
        MetricCard(
          label: 'Current Stock',
          value: '${product.stockQuantity}',
          caption: status.label,
          captionTone: product.isOutOfStock
              ? StatusTone.danger
              : product.isLowStock
              ? StatusTone.warning
              : null,
          icon: Icons.inventory_2_outlined,
          tone: StatusTone.brand,
        ),
        if (isOwner)
          MetricCard(
            label: 'Profit Margin',
            value: '${product.profitMargin.toStringAsFixed(1)}%',
            caption: 'Of the selling price',
            icon: Icons.trending_up_rounded,
            tone: StatusTone.success,
          ),
      ],
    );

    final information = InfoSection(
      title: 'Product Information',
      items: [
        InfoItem(label: 'Category', value: category),
        InfoItem(label: 'SKU', value: product.sku, placeholder: 'Not assigned'),
        InfoItem(
          label: 'Barcode',
          value: product.barcode,
          placeholder: 'Not assigned',
        ),
        InfoItem(label: 'Product ID', value: product.id),
        if (product.description?.trim().isNotEmpty == true)
          InfoItem(
            label: 'Description',
            value: product.description,
            wide: true,
          ),
      ],
    );

    final stock = InfoSection(
      title: 'Inventory',
      items: [
        InfoItem(
          label: 'Low Stock Level',
          value: '${product.lowStockThreshold}',
        ),
        InfoItem(label: 'Status', value: status.label),
      ],
    );

    // Owner-level figures behind the selling price.
    final pricing = isOwner
        ? InfoSection(
            title: 'Pricing',
            items: [
              InfoItem(
                label: 'Cost Price',
                value: formatGhs(product.costPrice),
              ),
              InfoItem(
                label: 'Profit / Unit',
                value: formatGhs(product.profitPerUnit),
              ),
            ],
          )
        : null;

    final danger = isOwner ? _DeleteSection(onDelete: onDelete) : null;

    const gap = SizedBox(height: AppSpacing.xxl);

    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity,
          const SizedBox(height: AppSpacing.lg),
          metrics,
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: information),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?pricing,
                    if (pricing != null) gap,
                    stock,
                    if (danger != null) ...[gap, danger],
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identity,
        const SizedBox(height: AppSpacing.lg),
        metrics,
        gap,
        if (pricing != null) ...[pricing, gap],
        stock,
        gap,
        information,
        if (danger != null) ...[gap, danger],
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});

  final Product product;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return ProductThumb(product: product, size: _size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: _size,
        height: _size,
        color: AppColors.surfaceMuted,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) =>
              InitialAvatar(name: product.name, size: _size),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Owner-only: removing the product, kept apart from everyday actions.
class _DeleteSection extends StatelessWidget {
  const _DeleteSection({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remove product',
            style: textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Deleting removes this product from your catalogue.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete Product'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 112, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 104, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.xxl),
        SkeletonBox(height: 200, radius: AppRadius.lg),
      ],
    );
  }
}
