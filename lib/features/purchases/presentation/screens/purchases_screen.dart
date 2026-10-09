import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/purchase.dart';
import '../providers/purchases_provider.dart';
import '../widgets/purchase_card.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

enum _PaymentFilter { all, outstanding, paid }

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  _PaymentFilter _filter = _PaymentFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Purchase> _filterPurchases(List<Purchase> purchases) {
    final query = _searchQuery.trim().toLowerCase();

    return purchases.where((purchase) {
      final matchesFilter = switch (_filter) {
        _PaymentFilter.all => true,
        _PaymentFilter.outstanding => purchase.hasBalance,
        _PaymentFilter.paid => purchase.isFullyPaid,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final purchaseNumber = purchase.purchaseNumber.toLowerCase();
      final supplier = purchase.supplierName?.toLowerCase() ?? '';
      final phone = purchase.supplierPhone?.toLowerCase() ?? '';

      return purchaseNumber.contains(query) ||
          supplier.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(purchasesProvider);
    await ref.read(purchasesProvider.future);
  }

  void _newPurchase() => context.push('/purchases/new');

  void _open(Purchase purchase) => context.push('/purchases/${purchase.id}');

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final isCompact = Breakpoints.ofWindow(context).isCompact;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              heroTag: 'purchases_fab',
              onPressed: _newPurchase,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('New Purchase'),
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

            final header = Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isCompact ? AppSpacing.md : AppSpacing.xxl,
                horizontal,
                AppSpacing.xl,
              ),
              child: PageHeader(
                title: 'Purchases',
                subtitle: 'Stock bought from your suppliers',
                leading: pageHeaderLeading(context),
                actions: [
                  if (!isCompact)
                    PrimaryButton(
                      label: 'New Purchase',
                      icon: Icons.add_shopping_cart_rounded,
                      onPressed: _newPurchase,
                    ),
                ],
              ),
            );

            return purchasesAsync.when(
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
                      title: 'Unable to load purchases',
                      message: 'Check your connection and try again.',
                      onRetry: _refresh,
                    ),
                  ),
                ],
              ),
              data: (purchases) => RefreshIndicator(
                onRefresh: _refresh,
                child: _buildContent(purchases, header, horizontal, isCompact),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    List<Purchase> purchases,
    Widget header,
    double horizontal,
    bool isCompact,
  ) {
    final filteredPurchases = _filterPurchases(purchases);

    final totalPurchases = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.totalAmount,
    );
    final totalPaid = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.amountPaid,
    );
    final outstanding = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.balance,
    );
    final owing = purchases.where((purchase) => purchase.hasBalance).length;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: header),
        if (purchases.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              0,
              horizontal,
              AppSpacing.xxl,
            ),
            sliver: SliverToBoxAdapter(
              child: MetricGrid(
                cards: [
                  MetricCard(
                    label: 'Total Purchases',
                    value: formatGhs(totalPurchases),
                    caption:
                        '${purchases.length} '
                        '${purchases.length == 1 ? 'purchase' : 'purchases'}',
                    icon: Icons.shopping_bag_outlined,
                    emphasized: true,
                  ),
                  MetricCard(
                    label: 'Paid',
                    value: formatGhs(totalPaid),
                    caption: 'Paid to suppliers',
                    icon: Icons.check_circle_outline_rounded,
                    tone: StatusTone.success,
                  ),
                  MetricCard(
                    label: 'Outstanding',
                    value: formatGhs(outstanding),
                    caption: owing == 0
                        ? 'Nothing owed'
                        : 'Owed on $owing '
                              '${owing == 1 ? 'purchase' : 'purchases'}',
                    captionTone: owing == 0 ? null : StatusTone.warning,
                    icon: Icons.account_balance_wallet_outlined,
                    tone: StatusTone.warning,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            sliver: SliverToBoxAdapter(
              child: AppSearchField(
                controller: _searchController,
                hintText: 'Search purchase or supplier...',
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
                  (_PaymentFilter.all, 'All'),
                  (_PaymentFilter.outstanding, 'Outstanding'),
                  (_PaymentFilter.paid, 'Paid'),
                ])
                  AppFilterChip(
                    label: label,
                    selected: _filter == filter,
                    onSelected: () => setState(() => _filter = filter),
                  ),
              ],
            ),
          ),
        ],
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            0,
            horizontal,
            isCompact ? 96 : AppSpacing.xxxl,
          ),
          sliver: filteredPurchases.isEmpty
              ? SliverToBoxAdapter(
                  child: SurfaceCard(
                    child: purchases.isEmpty
                        ? EmptyState(
                            icon: Icons.shopping_bag_outlined,
                            title: 'No purchases yet',
                            message: 'Purchases you record will appear here.',
                            actionLabel: 'New Purchase',
                            actionIcon: Icons.add_shopping_cart_rounded,
                            onAction: _newPurchase,
                          )
                        : const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No purchases found',
                            message:
                                'Try a different purchase number, supplier '
                                'or filter.',
                          ),
                  ),
                )
              : SliverAdaptiveDataTable<Purchase>(
                  rows: filteredPurchases,
                  onRowTap: _open,
                  compactRowBuilder: (context, purchase) => PurchaseCard(
                    purchase: purchase,
                    onTap: () => _open(purchase),
                  ),
                  columns: _columns,
                ),
        ),
      ],
    );
  }

  static final List<DataColumnSpec<Purchase>> _columns = [
    DataColumnSpec<Purchase>(
      label: 'Purchase',
      flex: 3,
      compare: (a, b) => a.purchaseNumber.compareTo(b.purchaseNumber),
      cell: (purchase) => Text(
        purchase.purchaseNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    DataColumnSpec<Purchase>(
      label: 'Supplier',
      flex: 3,
      compare: (a, b) => purchaseSupplierLabel(
        a,
      ).toLowerCase().compareTo(purchaseSupplierLabel(b).toLowerCase()),
      cell: (purchase) => Text(
        purchaseSupplierLabel(purchase),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Purchase>(
      label: 'Date',
      flex: 2,
      visibleFrom: WindowSize.expanded,
      compare: (a, b) => a.purchaseDate.compareTo(b.purchaseDate),
      cell: (purchase) => Text(
        formatShortDate(purchase.purchaseDate),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Purchase>(
      label: 'Status',
      flex: 2,
      cell: (purchase) => Align(
        alignment: Alignment.centerLeft,
        child: PurchaseStatusBadge(purchase: purchase),
      ),
    ),
    DataColumnSpec<Purchase>(
      label: 'Balance',
      flex: 2,
      numeric: true,
      compare: (a, b) => a.balance.compareTo(b.balance),
      cell: (purchase) => Text(
        purchase.hasBalance ? formatGhs(purchase.balance) : '—',
        style: AppTypography.amount.copyWith(
          color: purchase.hasBalance ? AppColors.warning : AppColors.textMuted,
        ),
      ),
    ),
    DataColumnSpec<Purchase>(
      label: 'Total',
      flex: 2,
      numeric: true,
      compare: (a, b) => a.totalAmount.compareTo(b.totalAmount),
      cell: (purchase) =>
          Text(formatGhs(purchase.totalAmount), style: AppTypography.amount),
    ),
  ];
}
