import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';
import '../widgets/sale_card.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchController = TextEditingController();

  /// Payment method filter; null shows every sale.
  String? _paymentFilter;
  String _searchQuery = '';

  static const _paymentFilters = <(String?, String)>[
    (null, 'All'),
    ('cash', 'Cash'),
    ('mobile_money', 'Mobile Money'),
    ('card', 'Card'),
    ('bank_transfer', 'Bank Transfer'),
    ('credit', 'Credit'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _newSale() => context.push('/sales/new');

  void _open(Sale sale) => context.push('/sales/${sale.id}');

  Future<void> _refresh() async {
    ref.invalidate(salesProvider);
    await ref.read(salesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);
    final isCompact = Breakpoints.ofWindow(context).isCompact;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Phones get the thumb-reachable button; wider layouts put it in the
      // page header.
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              heroTag: 'sales_fab',
              onPressed: _newSale,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Sale'),
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
                title: 'Sales',
                subtitle: 'Every sale recorded in your shop',
                showMenuButton: true,
                actions: [
                  if (!isCompact)
                    PrimaryButton(
                      label: 'New Sale',
                      icon: Icons.add_rounded,
                      onPressed: _newSale,
                    ),
                ],
              ),
            );

            return salesAsync.when(
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
                      title: 'Unable to load sales',
                      message: 'Check your connection and try again.',
                      onRetry: () => ref.invalidate(salesProvider),
                    ),
                  ),
                ],
              ),
              data: (sales) => RefreshIndicator(
                onRefresh: _refresh,
                child: _buildContent(sales, header, horizontal, isCompact),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    List<Sale> sales,
    Widget header,
    double horizontal,
    bool isCompact,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = sales.where((sale) {
      final matchesPayment =
          _paymentFilter == null || sale.paymentMethod == _paymentFilter;
      final matchesSearch =
          query.isEmpty || sale.saleNumber.toLowerCase().contains(query);
      return matchesPayment && matchesSearch;
    }).toList();

    final total = sales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
    final creditSales = sales.where((sale) => sale.isCredit).toList();
    final creditTotal = creditSales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: header),
        if (sales.isNotEmpty)
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
                    label: 'Total Sales',
                    value: formatGhs(total),
                    caption: 'Across all recorded sales',
                    icon: Icons.payments_outlined,
                    emphasized: true,
                  ),
                  MetricCard(
                    label: 'Transactions',
                    value: '${sales.length}',
                    caption: sales.isEmpty
                        ? 'No sales yet'
                        : 'Average ${formatGhs(total / sales.length)}',
                    icon: Icons.receipt_long_outlined,
                    tone: StatusTone.info,
                  ),
                  MetricCard(
                    label: 'On Credit',
                    value: formatGhs(creditTotal),
                    caption: creditSales.isEmpty
                        ? 'No credit sales'
                        : '${creditSales.length} credit '
                              '${creditSales.length == 1 ? 'sale' : 'sales'}',
                    captionTone: creditSales.isEmpty
                        ? null
                        : StatusTone.warning,
                    icon: Icons.schedule_rounded,
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
              hintText: 'Search by sale number...',
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
              for (final (key, label) in _paymentFilters)
                AppFilterChip(
                  label: label,
                  selected: key == _paymentFilter,
                  onSelected: () => setState(() => _paymentFilter = key),
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
          sliver: filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: SurfaceCard(
                    child: sales.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No sales yet',
                            message: 'Completed sales will appear here.',
                            actionLabel: 'New Sale',
                            onAction: _newSale,
                          )
                        : const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No sales found',
                            message:
                                'Try a different sale number or payment '
                                'method.',
                          ),
                  ),
                )
              : SliverAdaptiveDataTable<Sale>(
                  rows: filtered,
                  onRowTap: _open,
                  compactRowBuilder: (context, sale) =>
                      SaleCard(sale: sale, onTap: () => _open(sale)),
                  columns: _columns,
                ),
        ),
      ],
    );
  }

  static final List<DataColumnSpec<Sale>> _columns = [
    DataColumnSpec<Sale>(
      label: 'Sale',
      flex: 3,
      compare: (a, b) => a.saleNumber.compareTo(b.saleNumber),
      cell: (sale) => Text(
        sale.saleNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    DataColumnSpec<Sale>(
      label: 'Date',
      flex: 3,
      compare: (a, b) => a.createdAt.compareTo(b.createdAt),
      cell: (sale) => Text(
        formatDateTime(sale.createdAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Sale>(
      label: 'Payment',
      flex: 2,
      cell: (sale) => Align(
        alignment: Alignment.centerLeft,
        child: SalePaymentBadge(sale: sale),
      ),
    ),
    DataColumnSpec<Sale>(
      label: 'Paid',
      flex: 2,
      numeric: true,
      visibleFrom: WindowSize.expanded,
      cell: (sale) => Text(
        formatGhs(sale.amountPaid),
        style: AppTypography.amount.copyWith(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Sale>(
      label: 'Total',
      flex: 2,
      numeric: true,
      compare: (a, b) => a.totalAmount.compareTo(b.totalAmount),
      cell: (sale) =>
          Text(formatGhs(sale.totalAmount), style: AppTypography.amount),
    ),
  ];
}
