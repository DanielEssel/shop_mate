import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/purchase.dart';
import '../../domain/entities/purchase_item.dart';
import '../providers/purchases_provider.dart';
import '../widgets/purchase_card.dart';

class PurchaseDetailsScreen extends ConsumerWidget {
  const PurchaseDetailsScreen({super.key, required this.purchaseId});

  final String purchaseId;

  void _invalidate(WidgetRef ref) {
    ref.invalidate(purchaseProvider(purchaseId));
    ref.invalidate(purchaseItemsProvider(purchaseId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseAsync = ref.watch(purchaseProvider(purchaseId));
    final itemsAsync = ref.watch(purchaseItemsProvider(purchaseId));

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

            return RefreshIndicator(
              onRefresh: () async {
                _invalidate(ref);
                await ref.read(purchaseProvider(purchaseId).future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                      title: 'Purchase Details',
                      leading: pageHeaderLeading(context),
                      actions: [
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => _invalidate(ref),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    purchaseAsync.when(
                      loading: () => const _DetailsSkeleton(),
                      error: (error, stackTrace) => SurfaceCard(
                        child: ErrorState(
                          compact: true,
                          title: 'Unable to load purchase',
                          message: error.toString(),
                          onRetry: () => _invalidate(ref),
                        ),
                      ),
                      data: (purchase) => _PurchaseDetailsBody(
                        purchase: purchase,
                        itemsAsync: itemsAsync,
                        wide: width >= Breakpoints.expanded,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PurchaseDetailsBody extends StatelessWidget {
  const _PurchaseDetailsBody({
    required this.purchase,
    required this.itemsAsync,
    required this.wide,
  });

  final Purchase purchase;
  final AsyncValue<List<PurchaseItem>> itemsAsync;

  /// Desktop: items beside the supplier and payment information.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.xxl);
    final notes = purchase.notes?.trim();

    final identity = IdentityPanel(
      visual: const IconTile(icon: Icons.shopping_bag_outlined, size: 56),
      title: purchase.purchaseNumber,
      subtitle:
          '${purchaseSupplierLabel(purchase)} · '
          '${formatShortDate(purchase.purchaseDate)}',
      badges: [
        _PurchaseStatusBadge(status: purchase.status),
        PurchaseStatusBadge(purchase: purchase),
      ],
    );

    final figures = MetricGrid(
      cards: [
        MetricCard(
          label: 'Total',
          value: formatGhs(purchase.totalAmount),
          caption: _paymentMethodLabel(purchase.paymentMethod),
          icon: Icons.shopping_bag_outlined,
          emphasized: true,
        ),
        MetricCard(
          label: 'Amount Paid',
          value: formatGhs(purchase.amountPaid),
          caption: 'Paid to the supplier',
          icon: Icons.check_circle_outline_rounded,
          tone: StatusTone.success,
        ),
        MetricCard(
          label: 'Balance',
          value: formatGhs(purchase.balance),
          caption: purchase.hasBalance ? 'Still owed' : 'Fully paid',
          captionTone: purchase.hasBalance ? StatusTone.warning : null,
          icon: Icons.account_balance_wallet_outlined,
          tone: StatusTone.warning,
        ),
      ],
    );

    final lineItems = itemsAsync.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Purchased Products'),
          SizedBox(height: AppSpacing.md),
          SkeletonList(rows: 3),
        ],
      ),
      error: (error, stackTrace) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Purchased Products'),
          const SizedBox(height: AppSpacing.md),
          SurfaceCard(
            child: ErrorState(
              compact: true,
              title: 'Unable to load purchase items',
              message: error.toString(),
            ),
          ),
        ],
      ),
      data: (items) => LineItemsSection(
        title: 'Purchased Products',
        unitLabel: 'Unit Cost',
        items: [
          for (final item in items)
            LineItem(
              name: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitCost,
              total: item.subtotal,
            ),
        ],
        total: purchase.totalAmount,
        emptyMessage: 'No purchase items found.',
      ),
    );

    final supplier = InfoSection(
      title: 'Supplier',
      items: [
        InfoItem(label: 'Name', value: purchase.supplierName),
        InfoItem(label: 'Phone', value: purchase.supplierPhone),
      ],
    );

    final payment = InfoSection(
      title: 'Payment',
      items: [
        InfoItem(
          label: 'Payment method',
          value: _paymentMethodLabel(purchase.paymentMethod),
        ),
        InfoItem(
          label: 'Payment status',
          value: purchase.isFullyPaid ? 'Fully Paid' : 'Outstanding',
        ),
        InfoItem(
          label: 'Purchase date',
          value: formatShortDate(purchase.purchaseDate),
        ),
        InfoItem(label: 'Status', value: _capitalize(purchase.status)),
      ],
    );

    final notesSection = notes == null || notes.isEmpty
        ? null
        : InfoSection(
            title: 'Notes',
            items: [InfoItem(label: 'Notes', value: notes, wide: true)],
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
                  children: [
                    supplier,
                    gap,
                    payment,
                    if (notesSection != null) ...[gap, notesSection],
                  ],
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
        supplier,
        gap,
        lineItems,
        gap,
        payment,
        if (notesSection != null) ...[gap, notesSection],
      ],
    );
  }
}

/// The purchase record's status (completed, cancelled, ...), as text with
/// an icon so it never relies on colour alone.
class _PurchaseStatusBadge extends StatelessWidget {
  const _PurchaseStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    if (normalized == 'completed') {
      return const StatusBadge(
        label: 'Completed',
        tone: StatusTone.neutral,
        icon: Icons.check_rounded,
      );
    }
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return StatusBadge(
        label: _capitalize(status),
        tone: StatusTone.danger,
        icon: Icons.block_rounded,
      );
    }
    return StatusBadge(
      label: _capitalize(status),
      tone: StatusTone.warning,
      icon: Icons.schedule_rounded,
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

// =============================================================
// HELPERS
// =============================================================

String _paymentMethodLabel(String method) {
  switch (method.toLowerCase()) {
    case 'mobile_money':
      return 'Mobile Money';
    case 'bank_transfer':
      return 'Bank Transfer';
    case 'cash':
      return 'Cash';
    case 'card':
      return 'Card';
    case 'credit':
      return 'Credit';
    default:
      return _capitalize(method);
  }
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}
