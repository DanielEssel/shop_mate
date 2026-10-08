import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/supplier.dart';
import '../providers/supplier_providers.dart';
import '../widgets/supplier_card.dart';

/// Supplier list with client-side search over the loaded suppliers and a
/// server-backed Active/Inactive/All filter.
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchController = TextEditingController();

  SupplierStatusFilter _filter = SupplierStatusFilter.active;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query == _query) return;
    setState(() => _query = query);
  }

  Future<void> _refresh() async {
    ref.invalidate(suppliersByStatusProvider(_filter));
    try {
      await ref.read(suppliersByStatusProvider(_filter).future);
    } catch (_) {
      // Shown inline by the error state.
    }
  }

  void _openAddSupplier() {
    context.push('/suppliers/new');
  }

  void _open(Supplier supplier) => context.push('/suppliers/${supplier.id}');

  void _setFilter(SupplierStatusFilter filter) {
    setState(() => _filter = filter);
  }

  List<Supplier> _search(List<Supplier> suppliers) {
    if (_query.isEmpty) return suppliers;

    return suppliers
        .where((supplier) {
          return supplier.name.toLowerCase().contains(_query) ||
              (supplier.phone?.toLowerCase().contains(_query) ?? false) ||
              (supplier.email?.toLowerCase().contains(_query) ?? false);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersByStatusProvider(_filter));
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
                        title: 'Suppliers',
                        subtitle: 'Supplier contacts for your shop',
                        leading: pageHeaderLeading(context),
                        actions: [
                          // Pull-to-refresh needs touch; mouse users get a
                          // button.
                          if (!isCompact)
                            IconButton(
                              tooltip: 'Refresh suppliers',
                              onPressed: suppliersAsync.isLoading
                                  ? null
                                  : _refresh,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          PrimaryButton(
                            label: 'Add supplier',
                            icon: Icons.add_business_outlined,
                            onPressed: _openAddSupplier,
                          ),
                        ],
                      ),
                    ),
                  ),
                  boxed(
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Search name, phone or email...',
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
                        for (final filter in SupplierStatusFilter.values)
                          AppFilterChip(
                            label: filter.label,
                            selected: filter == _filter,
                            onSelected: () => _setFilter(filter),
                          ),
                      ],
                    ),
                  ),
                  ...suppliersAsync.when(
                    loading: () => [
                      boxed(
                        const SurfaceCard(
                          padding: EdgeInsets.zero,
                          child: SkeletonList(rows: 4),
                        ),
                      ),
                    ],
                    error: (_, _) => [
                      boxed(
                        SurfaceCard(
                          child: ErrorState(
                            compact: true,
                            title: 'Unable to load suppliers',
                            message: 'Check your connection and try again.',
                            retryLabel: 'Retry',
                            onRetry: _refresh,
                          ),
                        ),
                      ),
                    ],
                    data: (suppliers) =>
                        _results(suppliers, horizontal: horizontal),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _results(
    List<Supplier> suppliers, {
    required double horizontal,
  }) {
    final results = _search(suppliers);
    const bottom = AppSpacing.xxxl;

    Widget message(Widget child) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottom),
        sliver: SliverToBoxAdapter(child: SurfaceCard(child: child)),
      );
    }

    if (suppliers.isEmpty) {
      if (_filter == SupplierStatusFilter.inactive) {
        return [
          message(
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No inactive suppliers',
              message: 'Suppliers you mark as inactive will appear here.',
              actions: [
                OutlinedButton(
                  onPressed: () => _setFilter(SupplierStatusFilter.active),
                  child: const Text('Show active suppliers'),
                ),
              ],
            ),
          ),
        ];
      }

      return [
        message(
          EmptyState(
            icon: Icons.storefront_outlined,
            title: _filter == SupplierStatusFilter.active
                ? 'No active suppliers'
                : 'No suppliers yet',
            message:
                'Add the suppliers you buy stock from to keep their contact '
                'details ready for purchasing.',
            actions: [
              PrimaryButton(
                label: 'Add supplier',
                icon: Icons.add_business_outlined,
                onPressed: _openAddSupplier,
              ),
              if (_filter == SupplierStatusFilter.active)
                OutlinedButton(
                  onPressed: () => _setFilter(SupplierStatusFilter.all),
                  child: const Text('Show all suppliers'),
                ),
            ],
          ),
        ),
      ];
    }

    if (results.isEmpty) {
      final scope = _filter == SupplierStatusFilter.all
          ? ''
          : '${_filter.label.toLowerCase()} ';

      return [
        message(
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No suppliers found',
            message: _query.isNotEmpty
                ? 'No ${scope}suppliers match your search.'
                : 'No suppliers match this filter.',
            actions: [
              OutlinedButton(
                onPressed: _searchController.clear,
                child: const Text('Clear search'),
              ),
              if (_filter != SupplierStatusFilter.all)
                OutlinedButton(
                  onPressed: () => _setFilter(SupplierStatusFilter.all),
                  child: const Text('Search all suppliers'),
                ),
            ],
          ),
        ),
      ];
    }

    final count = results.length;

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
            '$count ${count == 1 ? 'supplier' : 'suppliers'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottom),
        sliver: SliverAdaptiveDataTable<Supplier>(
          rows: results,
          onRowTap: _open,
          compactRowBuilder: (context, supplier) =>
              SupplierCard(supplier: supplier, onTap: () => _open(supplier)),
          columns: _columns,
        ),
      ),
    ];
  }

  static final List<DataColumnSpec<Supplier>> _columns = [
    DataColumnSpec<Supplier>(
      label: 'Supplier',
      flex: 4,
      compare: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      cell: (supplier) => Row(
        children: [
          InitialAvatar(name: supplier.name, size: 32),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              supplier.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
    DataColumnSpec<Supplier>(
      label: 'Phone',
      flex: 2,
      cell: (supplier) => _muted(supplier.phone),
    ),
    DataColumnSpec<Supplier>(
      label: 'Email',
      flex: 3,
      cell: (supplier) => _muted(supplier.email),
    ),
    DataColumnSpec<Supplier>(
      label: 'Address',
      flex: 3,
      visibleFrom: WindowSize.expanded,
      cell: (supplier) => _muted(supplier.address),
    ),
    DataColumnSpec<Supplier>(
      label: 'Status',
      flex: 2,
      cell: (supplier) => Align(
        alignment: Alignment.centerLeft,
        child: SupplierListStatusBadge(isActive: supplier.isActive),
      ),
    ),
  ];

  static Widget _muted(String? value) {
    final trimmed = value?.trim();
    final missing = trimmed == null || trimmed.isEmpty;
    return Text(
      missing ? '—' : trimmed,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: missing ? AppColors.textMuted : AppColors.textSecondary,
      ),
    );
  }
}
