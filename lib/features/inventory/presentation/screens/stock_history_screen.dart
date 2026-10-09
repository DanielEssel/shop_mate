import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../domain/entities/stock_movement.dart';
import '../providers/inventory_provider.dart';
import '../widgets/stock_movement_tile.dart';

class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
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
    if (widget.productId != null) {
      ref.invalidate(productStockMovementsProvider(widget.productId!));

      await ref.read(productStockMovementsProvider(widget.productId!).future);
      return;
    }

    ref.invalidate(stockMovementsProvider);
    await ref.read(stockMovementsProvider.future);
  }

  void _changeFilter(String value) {
    setState(() {
      _selectedFilter = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final movementsAsync = widget.productId != null
        ? ref.watch(productStockMovementsProvider(widget.productId!))
        : ref.watch(stockMovementsProvider);

    // Product names are a nicety: while they load or if they fail, the
    // movements still show.
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final productMap = {for (final product in products) product.id: product};
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
                        title: 'Stock History',
                        subtitle: 'Track every change made to your inventory',
                        leading: pageHeaderLeading(context),
                        actions: [
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  boxed(
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Search product, note or reference...',
                      onChanged: (_) {},
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
                        for (final filter in _filters)
                          AppFilterChip(
                            label: _filterLabel(filter),
                            selected: _selectedFilter == filter,
                            onSelected: () => _changeFilter(filter),
                          ),
                      ],
                    ),
                  ),
                  ...movementsAsync.when(
                    loading: () => [boxed(const SkeletonList())],
                    error: (error, stackTrace) => [
                      boxed(
                        SurfaceCard(
                          child: ErrorState(
                            compact: true,
                            title: 'Unable to load stock history',
                            message: '$error',
                            retryLabel: 'Retry',
                            onRetry: _refresh,
                          ),
                        ),
                      ),
                    ],
                    data: (movements) => _movementSlivers(
                      _filter(movements, productMap),
                      productMap: productMap,
                      horizontal: horizontal,
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

  List<StockMovement> _filter(
    List<StockMovement> movements,
    Map<String, Product> productMap,
  ) {
    return movements.where((movement) {
      final matchesType =
          _selectedFilter == 'all' ||
          movement.movementType.toLowerCase() == _selectedFilter;

      if (!matchesType) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      final product = productMap[movement.productId];

      final productName = product?.name.toLowerCase() ?? '';

      final note = movement.note?.toLowerCase() ?? '';

      final reference = movement.referenceId?.toLowerCase() ?? '';

      return productName.contains(_searchQuery) ||
          note.contains(_searchQuery) ||
          reference.contains(_searchQuery) ||
          movement.movementType.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<Widget> _movementSlivers(
    List<StockMovement> filtered, {
    required Map<String, Product> productMap,
    required double horizontal,
  }) {
    String? nameOf(StockMovement movement) =>
        productMap[movement.productId]?.name;

    void open(StockMovement movement) {
      showStockMovementDetails(
        context,
        movement: movement,
        productName: nameOf(movement),
      );
    }

    if (filtered.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            0,
            horizontal,
            AppSpacing.xxxl,
          ),
          sliver: const SliverToBoxAdapter(
            child: SurfaceCard(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'No stock movements found',
                message: 'Stock changes will appear here automatically.',
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontal + AppSpacing.xs,
          0,
          horizontal,
          AppSpacing.sm,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            '${filtered.length} ${filtered.length == 1 ? 'record' : 'records'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
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
        sliver: SliverAdaptiveDataTable<StockMovement>(
          rows: filtered,
          onRowTap: open,
          compactRowBuilder: (context, movement) => StockMovementTile(
            movement: movement,
            productName: nameOf(movement),
            onTap: () => open(movement),
          ),
          columns: [
            DataColumnSpec<StockMovement>(
              label: 'Product',
              flex: 4,
              cell: (movement) => Text(
                nameOf(movement) ?? 'Unknown product',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            DataColumnSpec<StockMovement>(
              label: 'Movement',
              flex: 3,
              cell: (movement) => Align(
                alignment: Alignment.centerLeft,
                child: StockMovementType.of(movement.movementType).badge(),
              ),
            ),
            DataColumnSpec<StockMovement>(
              label: 'Change',
              flex: 2,
              numeric: true,
              cell: (movement) => Align(
                alignment: Alignment.centerRight,
                child: StockChange(movement: movement),
              ),
            ),
            DataColumnSpec<StockMovement>(
              label: 'Stock',
              flex: 2,
              numeric: true,
              cell: (movement) => Align(
                alignment: Alignment.centerRight,
                child: StockLevels(movement: movement),
              ),
            ),
            DataColumnSpec<StockMovement>(
              label: 'Date',
              flex: 3,
              compare: (a, b) => a.createdAt.compareTo(b.createdAt),
              cell: (movement) => Text(
                formatDateTime(movement.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            DataColumnSpec<StockMovement>(
              label: 'Note',
              flex: 3,
              visibleFrom: WindowSize.expanded,
              cell: (movement) => Text(
                movement.note?.trim().isNotEmpty == true
                    ? movement.note!.trim()
                    : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    ];
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

/// Everything recorded about one movement, as a bottom sheet on phones and
/// a dialog on wider windows. Read-only: no stock can be changed here.
Future<void> showStockMovementDetails(
  BuildContext context, {
  required StockMovement movement,
  String? productName,
}) {
  final type = StockMovementType.of(movement.movementType);
  final increase = isStockIncrease(movement);
  final name = productName?.trim();

  return showAdaptiveSheet<void>(
    context,
    title: 'Stock Movement',
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              type.badge(),
              const Spacer(),
              StockChange(movement: movement),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          InfoSection(
            items: [
              InfoItem(
                label: 'Product',
                value: name == null || name.isEmpty ? null : name,
                placeholder: 'Unknown product',
                wide: true,
              ),
              InfoItem(
                label: increase ? 'Quantity added' : 'Quantity removed',
                value: '${movement.quantity}',
              ),
              InfoItem(label: 'Movement', value: type.label),
              InfoItem(
                label: 'Stock before',
                value: '${movement.previousQuantity}',
              ),
              InfoItem(label: 'Stock after', value: '${movement.newQuantity}'),
              InfoItem(
                label: 'Date',
                value: formatDateTime(movement.createdAt),
                wide: true,
              ),
              InfoItem(
                label: 'Reference',
                value: movement.referenceId,
                placeholder: 'None',
                wide: true,
              ),
              InfoItem(
                label: 'Note',
                value: movement.note,
                placeholder: 'None',
                wide: true,
              ),
            ],
          ),
        ],
      );
    },
  );
}
