import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../../product_categories/domain/entities/product_category.dart';
import '../../../product_categories/presentation/providers/product_category_providers.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';
import '../widgets/product_visuals.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  /// Filter keys: [_allFilter], [_noneFilter], or a category id.
  static const _allFilter = '__all__';
  static const _noneFilter = '__none__';

  String _searchQuery = '';
  String _selectedFilter = _allFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addProduct() => context.push('/products/new');

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isCompact = Breakpoints.ofWindow(context).isCompact;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Phones get the thumb-reachable button; wider layouts put it in the
      // page header.
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              heroTag: 'products_fab',
              onPressed: _addProduct,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = Breakpoints.pagePadding(
              constraints.maxWidth,
              maxWidth: ContentWidth.wide,
            );

            // While loading or failed the header stays, so the menu and
            // Add Product remain reachable.
            final header = Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isCompact ? AppSpacing.md : AppSpacing.xxl,
                horizontal,
                AppSpacing.lg,
              ),
              child: _header(null, isCompact),
            );

            return productsAsync.when(
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: PageSkeleton(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                    ),
                  ),
                ],
              ),
              error: (error, stackTrace) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: ErrorState(
                      title: 'Unable to load products.',
                      message: 'Check your connection and try again.',
                      onRetry: () => ref.invalidate(productsProvider),
                    ),
                  ),
                ],
              ),
              data: (products) =>
                  _buildContent(context, products, horizontal, isCompact),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Product> products,
    double horizontal,
    bool isCompact,
  ) {
    // Active categories only; products in archived categories stay visible
    // under "All". A failed category load just leaves "All".
    final categories =
        ref.watch(activeProductCategoriesProvider).value ??
        const <ProductCategory>[];

    // A selected category that is no longer active falls back to "All".
    final filter =
        _selectedFilter == _allFilter ||
            _selectedFilter == _noneFilter ||
            categories.any((category) => category.id == _selectedFilter)
        ? _selectedFilter
        : _allFilter;

    final filteredProducts = products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      final matchesCategory = switch (filter) {
        _allFilter => true,
        _noneFilter => product.categoryId == null,
        _ => product.categoryId == filter,
      };

      return matchesSearch && matchesCategory;
    }).toList();

    final filters = <(String, String)>[
      (_allFilter, 'All'),
      for (final category in categories) (category.id, category.name),
      (_noneFilter, 'No category'),
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            isCompact ? AppSpacing.md : AppSpacing.xxl,
            horizontal,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: _header(products.length, isCompact),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverToBoxAdapter(
            child: AppSearchField(
              controller: _searchController,
              hintText: 'Search products...',
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
              for (final (key, label) in filters)
                AppFilterChip(
                  label: label,
                  selected: key == filter,
                  onSelected: () => setState(() => _selectedFilter = key),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            0,
            horizontal,
            // Room for the floating button on phones.
            isCompact ? 96 : AppSpacing.xxxl,
          ),
          sliver: filteredProducts.isEmpty
              ? SliverToBoxAdapter(
                  child: SurfaceCard(
                    child: products.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products yet',
                            message:
                                'Add your first product to start selling and tracking stock.',
                          )
                        : const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No products found',
                            message:
                                'Try changing your search or category filter.',
                          ),
                  ),
                )
              : SliverAdaptiveDataTable<Product>(
                  rows: filteredProducts,
                  onRowTap: _open,
                  compactRowBuilder: (context, product) =>
                      _ProductListRow(product: product, onTap: _open),
                  columns: _columns,
                ),
        ),
      ],
    );
  }

  Widget _header(int? count, bool isCompact) {
    return PageHeader(
      title: 'Products',
      subtitle: count == null
          ? 'Products in your shop'
          : '$count products in your shop',
      showMenuButton: true,
      actions: [
        if (!isCompact)
          PrimaryButton(
            label: 'Add Product',
            icon: Icons.add_rounded,
            onPressed: _addProduct,
          ),
      ],
    );
  }

  void _open(Product product) => context.go('/products/${product.id}');

  static final List<DataColumnSpec<Product>> _columns = [
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
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Product>(
      label: 'SKU',
      flex: 2,
      visibleFrom: WindowSize.expanded,
      cell: (product) => Text(
        _nonEmpty(product.sku) ?? '—',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Product>(
      label: 'Price',
      flex: 2,
      numeric: true,
      compare: (a, b) => a.sellingPrice.compareTo(b.sellingPrice),
      cell: (product) =>
          Text(formatGhs(product.sellingPrice), style: AppTypography.amount),
    ),
    DataColumnSpec<Product>(
      label: 'Stock',
      flex: 1,
      numeric: true,
      compare: (a, b) => a.stockQuantity.compareTo(b.stockQuantity),
      cell: (product) =>
          Text('${product.stockQuantity}', style: AppTypography.amount),
    ),
    DataColumnSpec<Product>(
      label: 'Status',
      flex: 2,
      cell: (product) => ProductStockBadge(product: product),
    ),
  ];

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _ProductListRow extends StatelessWidget {
  const _ProductListRow({required this.product, required this.onTap});

  final Product product;
  final ValueChanged<Product> onTap;

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(product);

    return ProductRow(
      name: product.name,
      details: [product.categoryName ?? 'No category'],
      stockLabel: stockQuantityLabel(product),
      price: formatGhs(product.sellingPrice),
      statusLabel: status.label,
      statusTone: status.tone,
      leading: ProductThumb(product: product),
      onTap: () => onTap(product),
    );
  }
}
