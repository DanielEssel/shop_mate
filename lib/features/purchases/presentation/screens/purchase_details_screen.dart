import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/purchase.dart';
import '../../domain/entities/purchase_item.dart';
import '../providers/purchases_provider.dart';

class PurchaseDetailsScreen extends ConsumerWidget {
  const PurchaseDetailsScreen({
    super.key,
    required this.purchaseId,
  });

  final String purchaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseAsync = ref.watch(
      purchaseProvider(purchaseId),
    );

    final itemsAsync = ref.watch(
      purchaseItemsProvider(purchaseId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Purchase Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(
                purchaseProvider(purchaseId),
              );
              ref.invalidate(
                purchaseItemsProvider(purchaseId),
              );
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: purchaseAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _PurchaseErrorState(
            error: error,
            onRetry: () {
              ref.invalidate(
                purchaseProvider(purchaseId),
              );
              ref.invalidate(
                purchaseItemsProvider(purchaseId),
              );
            },
          );
        },
        data: (purchase) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                purchaseProvider(purchaseId),
              );
              ref.invalidate(
                purchaseItemsProvider(purchaseId),
              );

              await ref.read(
                purchaseProvider(purchaseId).future,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                40,
              ),
              children: [
                _PurchaseHeader(
                  purchase: purchase,
                ),
                const SizedBox(height: 16),
                _PurchaseSummaryCard(
                  purchase: purchase,
                ),
                const SizedBox(height: 16),
                _SupplierCard(
                  purchase: purchase,
                ),
                const SizedBox(height: 16),
                _PurchaseItemsCard(
                  itemsAsync: itemsAsync,
                ),
                if (purchase.notes != null &&
                    purchase.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _NotesCard(
                    notes: purchase.notes!,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// PURCHASE HEADER
// =============================================================

class _PurchaseHeader extends StatelessWidget {
  const _PurchaseHeader({
    required this.purchase,
  });

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF087F5B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Purchase',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      purchase.purchaseNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                status: purchase.status,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(purchase.purchaseDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// SUMMARY
// =============================================================

class _PurchaseSummaryCard extends StatelessWidget {
  const _PurchaseSummaryCard({
    required this.purchase,
  });

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Payment Summary',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _AmountRow(
            label: 'Total amount',
            amount: purchase.totalAmount,
            emphasized: true,
          ),
          const SizedBox(height: 12),
          _AmountRow(
            label: 'Amount paid',
            amount: purchase.amountPaid,
          ),
          const SizedBox(height: 12),
          _AmountRow(
            label: 'Balance',
            amount: purchase.balance,
            valueColor: purchase.hasBalance
                ? Colors.redAccent
                : const Color(0xFF087F5B),
            emphasized: purchase.hasBalance,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.payment_rounded,
                  label: 'Payment method',
                  value: _paymentMethodLabel(
                    purchase.paymentMethod,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  icon: Icons.verified_outlined,
                  label: 'Payment status',
                  value: purchase.isFullyPaid
                      ? 'Fully Paid'
                      : 'Outstanding',
                  valueColor: purchase.isFullyPaid
                      ? const Color(0xFF087F5B)
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// SUPPLIER
// =============================================================

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.purchase,
  });

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final hasSupplier =
        purchase.supplierName != null &&
        purchase.supplierName!.trim().isNotEmpty;

    final hasPhone =
        purchase.supplierPhone != null &&
        purchase.supplierPhone!.trim().isNotEmpty;

    return _SectionCard(
      title: 'Supplier',
      icon: Icons.storefront_outlined,
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: hasSupplier
                ? purchase.supplierName!
                : 'Not provided',
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: hasPhone
                ? purchase.supplierPhone!
                : 'Not provided',
          ),
        ],
      ),
    );
  }
}

// =============================================================
// ITEMS
// =============================================================

class _PurchaseItemsCard extends StatelessWidget {
  const _PurchaseItemsCard({
    required this.itemsAsync,
  });

  final AsyncValue<List<PurchaseItem>> itemsAsync;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Purchased Products',
      icon: Icons.inventory_2_outlined,
      child: itemsAsync.when(
        loading: () {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        error: (error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unable to load purchase items.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
        data: (items) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 20,
              ),
              child: Center(
                child: Text(
                  'No purchase items found.',
                ),
              ),
            );
          }

          return Column(
            children: [
              for (int index = 0;
                  index < items.length;
                  index++) ...[
                _PurchaseItemRow(
                  item: items[index],
                ),
                if (index < items.length - 1)
                  const Divider(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PurchaseItemRow extends StatelessWidget {
  const _PurchaseItemRow({
    required this.item,
  });

  final PurchaseItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5F0),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFF087F5B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${item.quantity} × GHS ${item.unitCost.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
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

// =============================================================
// NOTES
// =============================================================

class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.notes,
  });

  final String notes;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Notes',
      icon: Icons.notes_rounded,
      child: Text(
        notes,
        style: TextStyle(
          color: Colors.grey.shade700,
          height: 1.5,
        ),
      ),
    );
  }
}

// =============================================================
// SECTION CARD
// =============================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F0),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF087F5B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// =============================================================
// AMOUNT ROW
// =============================================================

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight:
                  emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          'GHS ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: emphasized ? 16 : 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// INFO TILE
// =============================================================

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: const Color(0xFF087F5B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
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

// =============================================================
// DETAIL ROW
// =============================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF087F5B),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// STATUS BADGE
// =============================================================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    final Color background;
    final Color foreground;

    if (normalized == 'completed') {
      background = Colors.white.withValues(
        alpha: 0.16,
      );
      foreground = Colors.white;
    } else if (normalized == 'cancelled' ||
        normalized == 'canceled') {
      background = Colors.red.withValues(
        alpha: 0.16,
      );
      foreground = Colors.white;
    } else {
      background = Colors.orange.withValues(
        alpha: 0.18,
      );
      foreground = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _capitalize(status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// =============================================================
// ERROR STATE
// =============================================================

class _PurchaseErrorState extends StatelessWidget {
  const _PurchaseErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
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
            const SizedBox(height: 12),
            const Text(
              'Unable to load purchase',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
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

  return value[0].toUpperCase() +
      value.substring(1).toLowerCase();
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} '
      '${date.day}, ${date.year}';
}