import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../providers/sales_provider.dart';

class SaleDetailsScreen extends ConsumerWidget {
  const SaleDetailsScreen({
    super.key,
    required this.saleId,
  });

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleProvider(saleId));
    final itemsAsync = ref.watch(saleItemsProvider(saleId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Sale Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(saleProvider(saleId));
              ref.invalidate(saleItemsProvider(saleId));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: saleAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
          onRetry: () {
            ref.invalidate(saleProvider(saleId));
            ref.invalidate(saleItemsProvider(saleId));
          },
        ),
        data: (sale) {
          return itemsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => _ErrorState(
              message: error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
              onRetry: () {
                ref.invalidate(saleItemsProvider(saleId));
              },
            ),
            data: (items) {
              return _SaleDetailsBody(
                sale: sale,
                items: items,
              );
            },
          );
        },
      ),
    );
  }
}

class _SaleDetailsBody extends StatelessWidget {
  const _SaleDetailsBody({
    required this.sale,
    required this.items,
  });

  final Sale sale;
  final List<SaleItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 900,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SaleHeader(sale: sale),
                const SizedBox(height: 16),
                _SaleSummaryCard(sale: sale),
                const SizedBox(height: 16),
                _ItemsCard(items: items),
                const SizedBox(height: 16),
                _PaymentCard(sale: sale),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.pop();
                    },
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                    ),
                    label: const Text('Back to Sales'),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sale ID: ${sale.id}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaleHeader extends StatelessWidget {
  const _SaleHeader({
    required this.sale,
  });

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF087F5B),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.saleNumber,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDateTime(sale.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            label: sale.isCredit ? 'Credit' : 'Completed',
            isCredit: sale.isCredit,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.isCredit,
  });

  final String label;
  final bool isCredit;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isCredit ? const Color(0xFFFFF4E5) : const Color(0xFFE8F5F0);

    final foregroundColor =
        isCredit ? const Color(0xFFB76E00) : const Color(0xFF087F5B);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SaleSummaryCard extends StatelessWidget {
  const _SaleSummaryCard({
    required this.sale,
  });

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sale Summary',
      icon: Icons.summarize_rounded,
      child: Column(
        children: [
          _InfoRow(
            label: 'Total amount',
            value: 'GHS ${sale.totalAmount.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Payment method',
            value: sale.paymentMethodLabel,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Amount paid',
            value: 'GHS ${sale.amountPaid.toStringAsFixed(2)}',
          ),
          if (!sale.isCredit) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Change',
              value: 'GHS ${sale.changeAmount.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.items,
  });

  final List<SaleItem> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Items',
      icon: Icons.shopping_bag_outlined,
      trailing: Text(
        '${items.length} ${items.length == 1 ? 'item' : 'items'}',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No items found for this sale.'),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _SaleItemRow(item: items[index]),
                  if (index != items.length - 1)
                    const Divider(height: 24),
                ],
              ],
            ),
    );
  }
}

class _SaleItemRow extends StatelessWidget {
  const _SaleItemRow({
    required this.item,
  });

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F3F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quantity} × GHS ${item.unitPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'GHS ${item.subtotal.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.sale,
  });

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Payment',
      icon: Icons.payments_outlined,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _paymentIcon(sale.paymentMethod),
              color: const Color(0xFF087F5B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.paymentMethodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sale.isCredit
                      ? 'Payment recorded as credit'
                      : 'Payment completed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing = const SizedBox.shrink(),
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: const Color(0xFF087F5B),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

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
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load sale',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();

  String twoDigits(int value) =>
      value.toString().padLeft(2, '0');

  return '${local.day}/${local.month}/${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

IconData _paymentIcon(String method) {
  switch (method) {
    case 'cash':
      return Icons.payments_rounded;
    case 'mobile_money':
      return Icons.phone_android_rounded;
    case 'card':
      return Icons.credit_card_rounded;
    case 'bank_transfer':
      return Icons.account_balance_rounded;
    case 'credit':
      return Icons.schedule_rounded;
    default:
      return Icons.payment_rounded;
  }
}
