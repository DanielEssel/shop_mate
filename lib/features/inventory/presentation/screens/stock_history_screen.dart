import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../domain/entities/stock_movement.dart';
import '../providers/inventory_provider.dart';
import '../widgets/stock_movement_tile.dart';

class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({
    super.key,
    this.productId,
  });

  final String? productId;

  @override
  ConsumerState<StockHistoryScreen> createState() =>
      _StockHistoryScreenState();
}

class _StockHistoryScreenState
    extends ConsumerState<StockHistoryScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'all';

  static const _filters = [
    'all',
    'sale',
    'purchase',
    'adjustment',
    'return',
    'opening',
  ];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (widget.productId != null) {
      ref.invalidate(
        productStockMovementsProvider(widget.productId!),
      );

      await ref.read(
        productStockMovementsProvider(widget.productId!).future,
      );
      return;
    }

    ref.invalidate(stockMovementsProvider);
    await ref.read(stockMovementsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final movementsAsync = widget.productId != null
        ? ref.watch(
            productStockMovementsProvider(widget.productId!),
          )
        : ref.watch(stockMovementsProvider);

    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Stock History',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: movementsAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _HistoryError(
            message: 'Unable to load stock history.\n$error',
            onRetry: _refresh,
          );
        },
        data: (movements) {
          return productsAsync.when(
            loading: () => _HistoryContent(
              movements: movements,
              products: const [],
              searchController: _searchController,
              searchQuery: _searchQuery,
              selectedFilter: _selectedFilter,
              filters: _filters,
              onFilterChanged: _changeFilter,
              onRefresh: _refresh,
            ),
            error: (_, _) => _HistoryContent(
              movements: movements,
              products: const [],
              searchController: _searchController,
              searchQuery: _searchQuery,
              selectedFilter: _selectedFilter,
              filters: _filters,
              onFilterChanged: _changeFilter,
              onRefresh: _refresh,
            ),
            data: (products) {
              return _HistoryContent(
                movements: movements,
                products: products,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedFilter: _selectedFilter,
                filters: _filters,
                onFilterChanged: _changeFilter,
                onRefresh: _refresh,
              );
            },
          );
        },
      ),
    );
  }

  void _changeFilter(String value) {
    setState(() {
      _selectedFilter = value;
    });
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.movements,
    required this.products,
    required this.searchController,
    required this.searchQuery,
    required this.selectedFilter,
    required this.filters,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final List<StockMovement> movements;
  final List<Product> products;
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedFilter;
  final List<String> filters;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final productMap = {
      for (final product in products) product.id: product,
    };

    final filtered = movements.where((movement) {
      final matchesType = selectedFilter == 'all' ||
          movement.movementType.toLowerCase() ==
              selectedFilter;

      if (!matchesType) {
        return false;
      }

      if (searchQuery.isEmpty) {
        return true;
      }

      final product =
          productMap[movement.productId];

      final productName =
          product?.name.toLowerCase() ?? '';

      final note =
          movement.note?.toLowerCase() ?? '';

      final reference =
          movement.referenceId?.toLowerCase() ?? '';

      return productName.contains(searchQuery) ||
          note.contains(searchQuery) ||
          reference.contains(searchQuery) ||
          movement.movementType
              .toLowerCase()
              .contains(searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop =
              constraints.maxWidth >= 1000;

          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              isDesktop ? 24 : 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1100,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Movement History',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Track every change made to your inventory.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),

                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search product, note or reference...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                        ),
                        suffixIcon:
                            searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed:
                                        searchController.clear,
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                    ),
                                  ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: filters.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = filters[index];
                          final selected =
                              selectedFilter == filter;

                          return ChoiceChip(
                            label: Text(
                              _filterLabel(filter),
                            ),
                            selected: selected,
                            onSelected: (_) {
                              onFilterChanged(filter);
                            },
                            selectedColor:
                                const Color(0xFFE8F5F1),
                            labelStyle: TextStyle(
                              color: selected
                                  ? const Color(0xFF087F5B)
                                  : Colors.grey.shade700,
                              fontWeight:
                                  selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF087F5B)
                                  : const Color(0xFFE9ECEF),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Stock Movements',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${filtered.length} records',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (filtered.isEmpty)
                      const _EmptyHistory()
                    else if (isDesktop)
                      _DesktopHistoryList(
                        movements: filtered,
                        products: productMap,
                      )
                    else
                      _MobileHistoryList(
                        movements: filtered,
                        products: productMap,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'sale':
        return 'Sales';
      case 'purchase':
        return 'Purchases';
      case 'adjustment':
        return 'Adjustments';
      case 'return':
        return 'Returns';
      case 'opening':
        return 'Opening';
      default:
        return filter;
    }
  }
}

class _DesktopHistoryList extends StatelessWidget {
  const _DesktopHistoryList({
    required this.movements,
    required this.products,
  });

  final List<StockMovement> movements;
  final Map<String, Product> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: movements.map((movement) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: StockMovementTile(
            movement: movement,
            productName:
                products[movement.productId]?.name,
          ),
        );
      }).toList(),
    );
  }
}

class _MobileHistoryList extends StatelessWidget {
  const _MobileHistoryList({
    required this.movements,
    required this.products,
  });

  final List<StockMovement> movements;
  final Map<String, Product> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: movements.map((movement) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: StockMovementTile(
            movement: movement,
            productName:
                products[movement.productId]?.name,
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 60,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 52,
            color: Colors.grey,
          ),
          SizedBox(height: 14),
          Text(
            'No stock movements found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Stock changes will appear here automatically.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}