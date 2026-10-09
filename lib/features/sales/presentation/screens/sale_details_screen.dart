import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../providers/sales_provider.dart';
import '../widgets/sale_card.dart';

class SaleDetailsScreen extends ConsumerWidget {
  const SaleDetailsScreen({super.key, required this.saleId});

  final String saleId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(saleProvider(saleId));
    ref.invalidate(saleItemsProvider(saleId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleProvider(saleId));
    final itemsAsync = ref.watch(saleItemsProvider(saleId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = Breakpoints.of(width).isCompact;
            final horizontal = Breakpoints.pagePadding(
              width,
              maxWidth: ContentWidth.standard,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isCompact ? AppSpacing.md : AppSpacing.xxl,
                horizontal,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: 'Sale Details',
                    leading: pageHeaderLeading(context),
                    actions: [
                      if (!isCompact)
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => _refresh(ref),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      PrimaryButton(
                        label: 'View receipt',
                        icon: Icons.receipt_long_outlined,
                        onPressed: () => context.push('/sales/$saleId/receipt'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  saleAsync.when(
                    loading: () => const _DetailsSkeleton(),
                    error: (error, _) => _LoadError(
                      title: 'Unable to load sale',
                      error: error,
                      onRetry: () => _refresh(ref),
                    ),
                    data: (sale) => itemsAsync.when(
                      loading: () => const _DetailsSkeleton(),
                      error: (error, _) => _LoadError(
                        title: 'Unable to load sale',
                        error: error,
                        onRetry: () =>
                            ref.invalidate(saleItemsProvider(saleId)),
                      ),
                      data: (items) => _SaleDetailsBody(
                        sale: sale,
                        items: items,
                        wide: width >= Breakpoints.expanded,
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

class _SaleDetailsBody extends StatelessWidget {
  const _SaleDetailsBody({
    required this.sale,
    required this.items,
    required this.wide,
  });

  final Sale sale;
  final List<SaleItem> items;

  /// Desktop: items beside the sale and payment information.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.xxl);

    final identity = IdentityPanel(
      visual: const IconTile(icon: Icons.receipt_long_outlined, size: 56),
      title: sale.saleNumber,
      subtitle: formatDateTime(sale.createdAt),
      badges: [
        sale.isCredit
            ? const StatusBadge(
                label: 'Credit',
                tone: StatusTone.warning,
                icon: Icons.schedule_rounded,
              )
            : const StatusBadge(
                label: 'Completed',
                tone: StatusTone.success,
                icon: Icons.check_circle_outline_rounded,
              ),
        // A credit sale's status already says "Credit".
        if (!sale.isCredit) SalePaymentBadge(sale: sale),
      ],
    );

    final figures = MetricGrid(
      cards: [
        MetricCard(
          label: 'Total',
          value: formatGhs(sale.totalAmount),
          caption:
              '${items.length} ${items.length == 1 ? 'product' : 'products'}',
          icon: Icons.payments_outlined,
          emphasized: true,
        ),
        MetricCard(
          label: 'Amount Paid',
          value: formatGhs(sale.amountPaid),
          caption: sale.paymentMethodLabel,
          icon: Icons.account_balance_wallet_outlined,
          tone: StatusTone.success,
        ),
        if (!sale.isCredit)
          MetricCard(
            label: 'Change',
            value: formatGhs(sale.changeAmount),
            caption: 'Given back to the customer',
            icon: Icons.currency_exchange_rounded,
            tone: StatusTone.info,
          ),
      ],
    );

    final lineItems = LineItemsSection(
      items: [
        for (final item in items)
          LineItem(
            name: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            total: item.subtotal,
          ),
      ],
      total: sale.totalAmount,
      emptyMessage: 'No items found for this sale.',
    );

    final information = InfoSection(
      title: 'Sale Information',
      items: [
        InfoItem(label: 'Sale number', value: sale.saleNumber),
        InfoItem(label: 'Date', value: formatDateTime(sale.createdAt)),
        InfoItem(
          label: 'Status',
          value: sale.isCredit ? 'Credit' : 'Completed',
        ),
        InfoItem(label: 'Sale ID', value: sale.id),
      ],
    );

    final payment = InfoSection(
      title: 'Payment',
      items: [
        InfoItem(label: 'Payment method', value: sale.paymentMethodLabel),
        InfoItem(
          label: 'Payment status',
          value: sale.isCredit
              ? 'Payment recorded as credit'
              : 'Payment completed',
        ),
      ],
    );

    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity,
          const SizedBox(height: AppSpacing.lg),
          figures,
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: lineItems),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [information, gap, payment],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identity,
        const SizedBox(height: AppSpacing.lg),
        figures,
        gap,
        lineItems,
        gap,
        payment,
        gap,
        information,
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: ErrorState(
        compact: true,
        title: title,
        message: error.toString().replaceFirst('Exception: ', ''),
        onRetry: onRetry,
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 112, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 104, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.xxl),
        SkeletonBox(height: 220, radius: AppRadius.lg),
      ],
    );
  }
}
