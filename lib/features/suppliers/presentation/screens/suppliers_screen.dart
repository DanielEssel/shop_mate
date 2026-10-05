import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/supplier.dart';
import '../providers/supplier_providers.dart';
import '../widgets/supplier_card.dart';
import '../widgets/supplier_search_bar.dart';

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
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Suppliers',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh suppliers',
            onPressed: suppliersAsync.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? AppSpacing.xl : AppSpacing.md,
                  isDesktop ? AppSpacing.lg : AppSpacing.sm,
                  isDesktop ? AppSpacing.xl : AppSpacing.md,
                  AppSpacing.xxxl,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(onAddSupplier: _openAddSupplier),
                          const SizedBox(height: AppSpacing.lg),
                          SupplierSearchBar(controller: _searchController),
                          const SizedBox(height: AppSpacing.md),
                          _StatusFilter(
                            selected: _filter,
                            onSelected: _setFilter,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          suppliersAsync.when(
                            loading: () => const _LoadingState(),
                            error: (_, _) => _ErrorState(onRetry: _refresh),
                            data: (suppliers) => _SupplierResults(
                              suppliers: suppliers,
                              results: _search(suppliers),
                              filter: _filter,
                              hasQuery: _query.isNotEmpty,
                              isDesktop: isDesktop,
                              onAddSupplier: _openAddSupplier,
                              onClearSearch: _searchController.clear,
                              onShowFilter: _setFilter,
                            ),
                          ),
                        ],
                      ),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.onAddSupplier});

  final VoidCallback onAddSupplier;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        Text(
          'Supplier contacts for your shop.',
          style: AppTypography.textTheme.bodyMedium!.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        FilledButton.icon(
          onPressed: onAddSupplier,
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Add supplier'),
        ),
      ],
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onSelected});

  final SupplierStatusFilter selected;
  final ValueChanged<SupplierStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final filter in SupplierStatusFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: filter == selected,
            onSelected: (_) => onSelected(filter),
          ),
      ],
    );
  }
}

class _SupplierResults extends StatelessWidget {
  const _SupplierResults({
    required this.suppliers,
    required this.results,
    required this.filter,
    required this.hasQuery,
    required this.isDesktop,
    required this.onAddSupplier,
    required this.onClearSearch,
    required this.onShowFilter,
  });

  final List<Supplier> suppliers;
  final List<Supplier> results;
  final SupplierStatusFilter filter;
  final bool hasQuery;
  final bool isDesktop;
  final VoidCallback onAddSupplier;
  final VoidCallback onClearSearch;
  final ValueChanged<SupplierStatusFilter> onShowFilter;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      if (filter == SupplierStatusFilter.inactive) {
        return _EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No inactive suppliers',
          message: 'Suppliers you mark as inactive will appear here.',
          actions: [
            OutlinedButton(
              onPressed: () => onShowFilter(SupplierStatusFilter.active),
              child: const Text('Show active suppliers'),
            ),
          ],
        );
      }

      return _EmptyState(
        icon: Icons.storefront_outlined,
        title: filter == SupplierStatusFilter.active
            ? 'No active suppliers'
            : 'No suppliers yet',
        message:
            'Add the suppliers you buy stock from to keep their contact '
            'details ready for purchasing.',
        actions: [
          FilledButton.icon(
            onPressed: onAddSupplier,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add supplier'),
          ),
          if (filter == SupplierStatusFilter.active)
            OutlinedButton(
              onPressed: () => onShowFilter(SupplierStatusFilter.all),
              child: const Text('Show all suppliers'),
            ),
        ],
      );
    }

    if (results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No suppliers found',
        message: hasQuery
            ? 'No ${filter == SupplierStatusFilter.all ? '' : '${filter.label.toLowerCase()} '}'
                  'suppliers match your search.'
            : 'No suppliers match this filter.',
        actions: [
          OutlinedButton(
            onPressed: onClearSearch,
            child: const Text('Clear search'),
          ),
          if (filter != SupplierStatusFilter.all)
            OutlinedButton(
              onPressed: () => onShowFilter(SupplierStatusFilter.all),
              child: const Text('Search all suppliers'),
            ),
        ],
      );
    }

    final count = results.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$count ${count == 1 ? 'supplier' : 'suppliers'}',
          style: AppTypography.textTheme.bodySmall!.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = isDesktop ? 2 : 1;
            final width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                columns;

            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final supplier in results)
                  SizedBox(
                    width: width,
                    child: SupplierCard(
                      supplier: supplier,
                      onTap: () => context.push('/suppliers/${supplier.id}'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.section),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Unable to load suppliers',
      message: 'Check your connection and try again.',
      actions: [
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
