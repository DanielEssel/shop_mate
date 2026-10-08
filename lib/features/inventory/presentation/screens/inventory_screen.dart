import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../../products/presentation/widgets/product_visuals.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/inventory_summary.dart';
import '../providers/inventory_provider.dart';

enum _StockFilter { all, low, out }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  _StockFilter _filter = _StockFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _invalidateStock() {
    ref.invalidate(productsProvider);
    ref.invalidate(inventorySummaryProvider);
    ref.invalidate(stockMovementsProvider);
  }

  Future<void> _refresh() async {
    _invalidateStock();
    await ref.read(productsProvider.future);
  }

  Future<void> _adjust([Product? product]) async {
    final result = await context.push<bool>(
      '/inventory/adjust',
      extra: product,
    );
    if (result == true) _invalidateStock();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final summaryAsync = ref.watch(inventorySummaryProvider);
    // Everyone can view inventory; stock adjustment is owner-only.
    final canAdjustStock = ref.watch(
      shopAccessProvider.select(selectIsShopOwner),
    );
    final isCompact = Breakpoints.ofWindow(context).isCompact;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = Breakpoints.pagePadding(
              constraints.maxWidth,
              maxWidth: ContentWidth.wide,
            );

            SliverPadding boxed(Widget child, {double bottom = 0}) {
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottom),
                sliver: SliverToBoxAdapter(child: child),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      isCompact ? AppSpacing.md : AppSpacing.xxl,
                      horizontal,
                      AppSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: PageHeader(
                        title: 'Inventory',
                        subtitle: 'Stock levels across your products',
                        showMenuButton: true,
                        actions: [
                          SecondaryButton(
                            label: 'Stock History',
                            icon: Icons.history_rounded,
                            onPressed: () => context.push('/inventory/history'),
                          ),
                          if (canAdjustStock)
                            PrimaryButton(
                              label: 'Adjust Stock',
                              icon: Icons.swap_vert_rounded,
                              onPressed: _adjust,
                            ),
                        ],
                      ),
                    ),
                  ),
                  boxed(
                    _StockMetrics(summaryAsync: summaryAsync),
                    bottom: AppSpacing.xxl,
                  ),
                  ...productsAsync.when(
                    loading: () => [
                      boxed(
                        const SurfaceCard(
                          padding: EdgeInsets.zero,
                          child: SkeletonList(),
                        ),
                      ),
                    ],
                    error: (error, stackTrace) => [
                      boxed(
                        SurfaceCard(
                          child: ErrorState(
                            compact: true,
                            title: 'Unable to load inventory.',
                            message: 'Check your connection and try again.',
                            onRetry: _refresh,
                          ),
                        ),
                      ),
                    ],
                    data: (products) => _productSlivers(
                      products,
                      horizontal: horizontal,
                      canAdjustStock: canAdjustStock,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _productSlivers(
    List<Product> products, {
    required double horizontal,
    required bool canAdjustStock,
  }) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = products.where((product) {
      final matchesFilter = switch (_filter) {
        _StockFilter.all => true,
        _StockFilter.low => product.isLowStock && !product.isOutOfStock,
        _StockFilter.out => product.isOutOfStock,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return product.name.toLowerCase().contains(query) ||
          (product.categoryName?.toLowerCase().contains(query) ?? false) ||
          (product.sku?.toLowerCase().contains(query) ?? false) ||
          (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();

    void open(Product product) => _adjust(product);

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        sliver: SliverToBoxAdapter(
          child: AppSearchField(
            controller: _searchController,
            hintText: 'Search name, category, SKU or barcode...',
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: FilterChipBar(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.md,
            horizontal,
            AppSpacing.lg,
          ),
          children: [
            for (final (filter, label) in const [
              (_StockFilter.all, 'All'),
              (_StockFilter.low, 'Low stock'),
              (_StockFilter.out, 'Out of stock'),
            ])
              AppFilterChip(
                label: label,
                selected: _filter == filter,
                onSelected: () => setState(() => _filter = filter),
              ),
          ],
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          0,
          horizontal,
          AppSpacing.xxxl,
        ),
        sliver: filtered.isEmpty
            ? SliverToBoxAdapter(
                child: SurfaceCard(
                  child: products.isEmpty
                      ? const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No products yet',
                          message:
                              'Products you add will appear here with their '
                              'stock levels.',
                        )
                      : const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No products found',
                          message: 'Try changing your search or filter.',
                        ),
                ),
              )
            : SliverAdaptiveDataTable<Product>(
                rows: filtered,
                // Opening a product here means adjusting it: owners only.
                onRowTap: canAdjustStock ? open : null,
                compactRowBuilder: (context, product) => _InventoryRow(
                  product: product,
                  onAdjust: canAdjustStock ? () => open(product) : null,
                ),
                columns: _columns(canAdjustStock ? open : null),
              ),
      ),
    ];
  }

  static List<DataColumnSpec<Product>> _columns(
    ValueChanged<Product>? onAdjust,
  ) {
    return [
      DataColumnSpec<Product>(
        label: 'Product',
        flex: 4,
        compare: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        cell: (product) => Row(
          children: [
            ProductThumb(product: product, size: 32),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
      DataColumnSpec<Product>(
        label: 'Category',
        flex: 2,
        cell: (product) => Text(
          product.categoryName ?? 'No category',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      DataColumnSpec<Product>(
        label: 'Reorder at',
        flex: 1,
        numeric: true,
        visibleFrom: WindowSize.expanded,
        cell: (product) => Text(
          '${product.lowStockThreshold}',
          style: AppTypography.amount.copyWith(color: AppColors.textMuted),
        ),
      ),
      DataColumnSpec<Product>(
        label: 'In stock',
        flex: 1,
        numeric: true,
        compare: (a, b) => a.stockQuantity.compareTo(b.stockQuantity),
        cell: (product) =>
            Text('${product.stockQuantity}', style: AppTypography.amount),
      ),
      DataColumnSpec<Product>(
        label: 'Status',
        flex: 2,
        compare: (a, b) => _severity(a).compareTo(_severity(b)),
        cell: (product) => Align(
          alignment: Alignment.centerLeft,
          child: ProductStockBadge(product: product),
        ),
      ),
      if (onAdjust != null)
        DataColumnSpec<Product>(
          label: '',
          flex: 1,
          numeric: true,
          cell: (product) => _AdjustButton(onPressed: () => onAdjust(product)),
        ),
    ];
  }

  /// Sort key: out of stock first, then low, then healthy.
  static int _severity(Product product) {
    if (product.isOutOfStock) return 0;
    if (product.isLowStock) return 1;
    return 2;
  }
}

/// Stock health figures. Units lead; low and out of stock carry their
/// semantic colour only when non-zero.
class _StockMetrics extends StatelessWidget {
  const _StockMetrics({required this.summaryAsync});

  final AsyncValue<InventorySummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const Row(
        children: [
          Expanded(child: SkeletonBox(height: 104, radius: 14)),
          SizedBox(width: AppSpacing.md),
          Expanded(child: SkeletonBox(height: 104, radius: 14)),
        ],
      ),
      error: (error, stackTrace) => Text(
        'Unable to load the stock summary.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      data: (summary) => MetricGrid(
        cards: [
          MetricCard(
            label: 'Stock Units',
            value: '${summary.totalStockUnits}',
            caption: 'Units on hand',
            icon: Icons.layers_outlined,
            emphasized: true,
          ),
          MetricCard(
            label: 'Products',
            value: '${summary.totalProducts}',
            caption: 'Active products',
            icon: Icons.inventory_2_outlined,
            tone: StatusTone.brand,
          ),
          MetricCard(
            label: 'Low Stock',
            value: '${summary.lowStockProducts}',
            caption: summary.lowStockProducts > 0
                ? 'Reorder soon'
                : 'Nothing running low',
            captionTone: summary.lowStockProducts > 0
                ? StatusTone.warning
                : null,
            icon: Icons.warning_amber_rounded,
            tone: StatusTone.warning,
            onTap: () => context.push('/inventory/low-stock'),
          ),
          MetricCard(
            label: 'Out of Stock',
            value: '${summary.outOfStockProducts}',
            caption: summary.outOfStockProducts > 0
                ? 'Unavailable to sell'
                : 'Everything available',
            captionTone: summary.outOfStockProducts > 0
                ? StatusTone.danger
                : null,
            icon: Icons.remove_shopping_cart_outlined,
            tone: StatusTone.danger,
          ),
        ],
      ),
    );
  }
}

/// A product's stock on phones: identity, quantity with status, and the
/// adjust action for owners.
class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.product, this.onAdjust});

  final Product product;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(product);
    final onAdjust = this.onAdjust;

    return ListRow(
      title: product.name,
      details: [product.categoryName ?? 'No category'],
      leading: ProductThumb(product: product),
      onTap: onAdjust,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        onAdjust == null ? AppSpacing.lg : AppSpacing.xs,
        AppSpacing.md,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RowValue(
            value: '${product.stockQuantity}',
            badge: StatusBadge(label: status.label, tone: status.tone),
          ),
          if (onAdjust != null) _AdjustButton(onPressed: onAdjust),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Adjust stock',
      onPressed: onPressed,
      color: AppColors.textSecondary,
      icon: const Icon(Icons.tune_rounded, size: 20),
    );
  }
}
