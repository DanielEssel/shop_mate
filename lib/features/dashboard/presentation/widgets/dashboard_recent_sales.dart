import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/recent_sale.dart';

/// Today's latest sales as compact transaction rows.
class DashboardRecentSales extends StatelessWidget {
  const DashboardRecentSales({super.key, required this.sales});

  final List<DashboardRecentSale> sales;

  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : local.hour == 0
        ? 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static IconData paymentIcon(String paymentMethod) {
    return switch (paymentMethod) {
      'mobile_money' => Icons.phone_android_rounded,
      'card' => Icons.credit_card_rounded,
      'bank_transfer' => Icons.account_balance_outlined,
      'credit' => Icons.schedule_rounded,
      _ => Icons.payments_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recent Sales',
          subtitle: 'Your latest transactions',
          actionLabel: 'View all',
          onAction: () => context.go('/sales'),
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: sales.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.receipt_long_outlined,
                  title: 'No recent sales',
                  message: 'Sales you record will appear here.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < sales.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      _row(context, sales[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, DashboardRecentSale sale) {
    final items = '${sale.itemCount} ${sale.itemCount == 1 ? 'item' : 'items'}';

    return TransactionRow(
      reference: sale.saleNumber,
      details: [items, sale.paymentMethodLabel],
      timestamp: formatTime(sale.createdAt),
      amount: formatGhs(sale.totalAmount),
      icon: paymentIcon(sale.paymentMethod),
      statusLabel: sale.paymentMethod == 'credit' ? 'Credit' : null,
      statusTone: StatusTone.warning,
      onTap: () => context.push('/sales/${sale.id}'),
    );
  }
}
