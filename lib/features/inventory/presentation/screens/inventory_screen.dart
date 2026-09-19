import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/inventory_product_card.dart';
import '../widgets/inventory_summary_card.dart';
import 'package:go_router/go_router.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(productsProvider);
    ref.invalidate(inventorySummaryProvider);
    ref.invalidate(stockMovementsProvider);

    await ref.read(productsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final summaryAsync = ref.watch(inventorySummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Inventory',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh inventory',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: productsAsync.when(
          loading: () {
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stackTrace) {
            return _InventoryError(
              message: 'Unable to load inventory.\n$error',
              onRetry: _refresh,
            );
          },
          data: (products) {
            final filteredProducts = _filterProducts(products);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1000;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(productCount: products.length),
                      const SizedBox(height: 20),

                      _SummarySection(
                        summaryAsync: summaryAsync,
                        isDesktop: isDesktop,
                      ),

                      const SizedBox(height: 28),

                      _InventoryQuickActions(
                        isDesktop: isDesktop,
                        onStockAdjusted: () {
                          ref.invalidate(productsProvider);
                          ref.invalidate(inventorySummaryProvider);
                          ref.invalidate(stockMovementsProvider);
                        },
                      ),

                      const SizedBox(height: 28),

                      _SearchBar(controller: _searchController),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Products',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${filteredProducts.length} items',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      if (filteredProducts.isEmpty)
                        const _EmptyInventory()
                      else if (isDesktop)
                        _DesktopProductGrid(products: filteredProducts)
                      else
                        _MobileProductList(products: filteredProducts),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_searchQuery.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(_searchQuery) ||
          product.category.toLowerCase().contains(_searchQuery) ||
          (product.sku?.toLowerCase().contains(_searchQuery) ?? false) ||
          (product.barcode?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock Overview',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          '$productCount active products in your inventory',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summaryAsync, required this.isDesktop});

  final AsyncValue summaryAsync;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () {
        return _SummaryLoading(isDesktop: isDesktop);
      },
      error: (error, stackTrace) {
        return const Text('Unable to load inventory summary.');
      },
      data: (summary) {
        final cards = [
          InventorySummaryCard(
            title: 'Total Products',
            value: '${summary.totalProducts}',
            subtitle: 'Active products',
            icon: Icons.inventory_2_outlined,
          ),
          InventorySummaryCard(
            title: 'Stock Units',
            value: '${summary.totalStockUnits}',
            subtitle: 'Units currently available',
            icon: Icons.layers_outlined,
          ),
          InventorySummaryCard(
            title: 'Low Stock',
            value: '${summary.lowStockProducts}',
            subtitle: 'Needs attention',
            icon: Icons.warning_amber_rounded,
          ),
          InventorySummaryCard(
            title: 'Out of Stock',
            value: '${summary.outOfStockProducts}',
            subtitle: 'Currently unavailable',
            icon: Icons.remove_shopping_cart_outlined,
          ),
        ];

        if (isDesktop) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (_, index) => cards[index],
          );
        }

        return SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              return SizedBox(width: 210, child: cards[index]);
            },
          ),
        );
      },
    );
  }
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final count = isDesktop ? 4 : 1;

    return SizedBox(
      height: 142,
      child: Row(
        children: List.generate(
          count,
          (index) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index == count - 1 ? 0 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search by product, category, SKU or barcode...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.clear_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DesktopProductGrid extends StatelessWidget {
  const _DesktopProductGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 430,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final product = products[index];

        return InventoryProductCard(
  product: product,
  onTap: () {
    context.push(
      '/inventory/adjust',
      extra: product,
    );
  },
  onAdjustStock: () {
    context.push(
      '/inventory/adjust',
      extra: product,
    );
  },
);
      },
    );
  }
}

class _MobileProductList extends StatelessWidget {
  const _MobileProductList({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = products[index];

        return InventoryProductCard(
  product: product,
  onTap: () {
    context.push(
      '/inventory/adjust',
      extra: product,
    );
  },
  onAdjustStock: () {
    context.push(
      '/inventory/adjust',
      extra: product,
    );
  },
);
      },
    );
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 52, color: Colors.grey),
          SizedBox(height: 14),
          Text(
            'No products found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text('Try changing your search.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InventoryError extends StatelessWidget {
  const _InventoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryQuickActions extends StatelessWidget {
  const _InventoryQuickActions({
    required this.isDesktop,
    required this.onStockAdjusted,
  });

  final bool isDesktop;
  final VoidCallback onStockAdjusted;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _InventoryAction(
        icon: Icons.swap_vert_rounded,
        title: 'Adjust Stock',
        subtitle: 'Correct or update stock quantities',
        onTap: () async {
          final result = await context.push<bool>('/inventory/adjust');

          if (result == true) {
            onStockAdjusted();
          }
        },
      ),
      _InventoryAction(
        icon: Icons.history_rounded,
        title: 'Stock History',
        subtitle: 'View all stock movements',
        onTap: () => context.push('/inventory/history'),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: actions.map((action) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: action == actions.first ? 12 : 0),
              child: action,
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: [actions[0], const SizedBox(height: 12), actions[1]],
    );
  }
}

class _InventoryAction extends StatelessWidget {
  const _InventoryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE7EAE8)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF087F5B), size: 24),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF087F5B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
