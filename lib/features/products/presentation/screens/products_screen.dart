import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../product_categories/domain/entities/product_category.dart';
import '../../../product_categories/presentation/providers/product_category_providers.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';
import '../widgets/product_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'products_fab',
        onPressed: () {
          context.push('/products/new');
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
      body: SafeArea(
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Unable to load products.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          data: (products) {
            return _buildContent(context, products);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Product> products) {
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(child: _buildHeader(context, products)),
        ),

        SliverToBoxAdapter(child: _buildFilters(filters, filter)),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            100,
          ),
          sliver: filteredProducts.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyProductsState())
              : SliverList.separated(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    return ProductCard(
                      product: product,
                      onTap: () {
                        context.go('/products/${product.id}');
                      },
                    );
                  },
                  separatorBuilder: (_, _) {
                    return const SizedBox(height: AppSpacing.sm);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<Product> products) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Products',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${products.length} products in your shop',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search products...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(List<(String, String)> filters, String selectedKey) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) {
          return const SizedBox(width: AppSpacing.sm);
        },
        itemBuilder: (context, index) {
          final (key, label) = filters[index];

          return FilterChip(
            selected: key == selectedKey,
            label: Text(label),
            onSelected: (_) {
              setState(() {
                _selectedFilter = key;
              });
            },
          );
        },
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Try changing your search or category filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
