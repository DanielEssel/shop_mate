import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/sale.dart';

/// A sale in a list: reference, when and how it was paid, and the total.
/// Credit sales carry a badge so money still owed stands out.
class SaleCard extends StatelessWidget {
  const SaleCard({super.key, required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TransactionRow(
      reference: sale.saleNumber,
      details: [sale.paymentMethodLabel],
      timestamp: formatDateTime(sale.createdAt),
      amount: formatGhs(sale.totalAmount),
      icon: salePaymentIcon(sale.paymentMethod),
      statusLabel: sale.isCredit ? 'Credit' : null,
      statusTone: StatusTone.warning,
      onTap: onTap,
    );
  }
}

/// The payment method as a badge; credit is highlighted as money owed.
class SalePaymentBadge extends StatelessWidget {
  const SalePaymentBadge({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: sale.paymentMethodLabel,
      tone: sale.isCredit ? StatusTone.warning : StatusTone.neutral,
      icon: salePaymentIcon(sale.paymentMethod),
    );
  }
}

IconData salePaymentIcon(String paymentMethod) {
  return switch (paymentMethod) {
    'mobile_money' => Icons.phone_android_rounded,
    'card' => Icons.credit_card_rounded,
    'bank_transfer' => Icons.account_balance_outlined,
    'credit' => Icons.schedule_rounded,
    _ => Icons.payments_outlined,
  };
}
