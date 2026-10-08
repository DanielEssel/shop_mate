import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/purchase.dart';

/// A purchase in a list: reference, supplier and date, the total, and
/// whether a balance is still owed.
class PurchaseCard extends StatelessWidget {
  const PurchaseCard({super.key, required this.purchase, required this.onTap});

  final Purchase purchase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TransactionRow(
      reference: purchase.purchaseNumber,
      details: [purchaseSupplierLabel(purchase)],
      timestamp: formatShortDate(purchase.purchaseDate),
      amount: formatGhs(purchase.totalAmount),
      icon: Icons.shopping_bag_outlined,
      statusLabel: purchase.hasBalance
          ? '${formatGhs(purchase.balance)} due'
          : 'Paid',
      statusTone: purchase.hasBalance ? StatusTone.warning : StatusTone.success,
      onTap: onTap,
    );
  }
}

/// Paid in full, or the balance still owed to the supplier.
class PurchaseStatusBadge extends StatelessWidget {
  const PurchaseStatusBadge({super.key, required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    return purchase.isFullyPaid
        ? const StatusBadge(label: 'Paid', tone: StatusTone.success)
        : const StatusBadge(label: 'Balance due', tone: StatusTone.warning);
  }
}

String purchaseSupplierLabel(Purchase purchase) {
  final name = purchase.supplierName?.trim();
  return name == null || name.isEmpty ? 'Unknown Supplier' : name;
}
