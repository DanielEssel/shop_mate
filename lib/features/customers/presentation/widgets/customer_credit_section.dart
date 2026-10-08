import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/customer_credit_statement.dart';
import '../providers/customers_provider.dart';
import 'record_customer_payment_sheet.dart';

/// A customer's credit account: totals, open credit sales and payments.
class CustomerCreditSection extends ConsumerWidget {
  const CustomerCreditSection({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statementAsync = ref.watch(
      customerCreditStatementProvider(customerId),
    );

    return statementAsync.when(
      loading: () => const _CreditSectionLoading(),
      error: (_, _) => _CreditSectionError(
        onRetry: () {
          ref.invalidate(customerCreditStatementProvider(customerId));
        },
      ),
      data: (statement) => _CreditStatementBody(
        customerId: customerId,
        customerName: customerName,
        statement: statement,
      ),
    );
  }
}

class _CreditStatementBody extends ConsumerWidget {
  const _CreditStatementBody({
    required this.customerId,
    required this.customerName,
    required this.statement,
  });

  final String customerId;
  final String customerName;
  final CustomerCreditStatement statement;

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    final wasRecorded = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.92,
            ),
            child: RecordCustomerPaymentSheet(
              customerId: customerId,
              customerName: customerName,
              outstandingSales: statement.outstandingSales,
            ),
          ),
        );
      },
    );

    if (wasRecorded != true || !context.mounted) return;

    ref.invalidate(customerCreditStatementProvider(customerId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Customer payment recorded.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOutstanding = statement.outstandingBalance > 0;
    const gap = SizedBox(height: AppSpacing.xxl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;
            final recordPayment = PrimaryButton(
              label: 'Record Payment',
              icon: Icons.payments_outlined,
              expand: narrow,
              onPressed: statement.outstandingSales.isEmpty
                  ? null
                  : () => _recordPayment(context, ref),
            );
            const heading = SectionHeader(
              title: 'Credit Account',
              subtitle: 'Credit sales and payments for this customer',
            );

            // Narrow screens: the action gets its own full-width row so the
            // heading is not squeezed.
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: AppSpacing.md),
                  recordPayment,
                ],
              );
            }

            return Row(
              children: [
                const Expanded(child: heading),
                const SizedBox(width: AppSpacing.md),
                recordPayment,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        MetricGrid(
          cards: [
            MetricCard(
              label: 'Outstanding',
              value: formatGhs(statement.outstandingBalance),
              caption: 'Current balance due',
              icon: Icons.account_balance_wallet_outlined,
              emphasized: hasOutstanding,
              tone: StatusTone.warning,
            ),
            MetricCard(
              label: 'Credit sales',
              value: formatGhs(statement.totalCreditSales),
              caption: 'Total credit sale value',
              icon: Icons.receipt_long_outlined,
              tone: StatusTone.info,
            ),
            MetricCard(
              label: 'Paid',
              value: formatGhs(statement.totalPaid),
              caption: 'Allocated payments',
              icon: Icons.payments_outlined,
              tone: StatusTone.success,
            ),
            MetricCard(
              label: 'Open credit sales',
              value: statement.outstandingSaleCount.toString(),
              caption: 'Sales with an outstanding balance',
              icon: Icons.pending_actions_outlined,
              tone: StatusTone.neutral,
            ),
          ],
        ),
        gap,
        const SectionHeader(title: 'Outstanding Credit Sales'),
        const SizedBox(height: AppSpacing.md),
        if (statement.totalCreditSales == 0)
          const _SectionEmptyState(
            message: 'No credit sales for this customer yet.',
          )
        else if (statement.outstandingSales.isEmpty)
          const _SectionEmptyState(message: 'No outstanding credit sales.')
        else
          _RowGroup(
            children: [
              for (final sale in statement.outstandingSales)
                _OutstandingSaleRow(sale: sale),
            ],
          ),
        gap,
        const SectionHeader(title: 'Payment History'),
        const SizedBox(height: AppSpacing.md),
        if (statement.paymentHistory.isEmpty)
          const _SectionEmptyState(message: 'No payments recorded yet.')
        else
          _RowGroup(
            children: [
              for (final payment in statement.paymentHistory)
                _PaymentHistoryRow(payment: payment),
            ],
          ),
      ],
    );
  }
}

/// Rows in one bordered section, divided by hairlines.
class _RowGroup extends StatelessWidget {
  const _RowGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const RowDivider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _OutstandingSaleRow extends StatelessWidget {
  const _OutstandingSaleRow({required this.sale});

  final OutstandingCreditSale sale;

  @override
  Widget build(BuildContext context) {
    return TransactionRow(
      reference: sale.saleNumber,
      details: [
        formatShortDate(sale.createdAt.toLocal()),
        'Total ${formatGhs(sale.totalAmount)}',
        'Paid ${formatGhs(sale.paidAmount)}',
      ],
      amount: formatGhs(sale.outstandingAmount),
      amountColor: AppColors.warning,
      icon: Icons.receipt_long_outlined,
      statusLabel: 'Due',
      statusTone: StatusTone.warning,
      onTap: () => context.push('/sales/${sale.id}'),
    );
  }
}

class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow({required this.payment});

  final CustomerPaymentHistoryEntry payment;

  @override
  Widget build(BuildContext context) {
    final reference = payment.reference?.trim();
    final note = payment.note?.trim();
    final textTheme = Theme.of(context).textTheme;
    final extra = [
      if (reference != null && reference.isNotEmpty) 'Reference: $reference',
      if (note != null && note.isNotEmpty) 'Note: $note',
      if (payment.allocatedSaleNumbers.isNotEmpty)
        'Allocated to ${payment.allocatedSaleNumbers.join(', ')}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransactionRow(
          reference: _paymentMethodLabel(payment.paymentMethod),
          details: [formatDateTime(payment.paidAt)],
          amount: formatGhs(payment.amount),
          icon: Icons.payments_outlined,
        ),
        // Longer details wrap under the row rather than being cut off.
        if (extra.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg + 36 + AppSpacing.md,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in extra)
                  Text(
                    line,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _paymentMethodLabel(String method) {
    return switch (method) {
      'mobile_money' => 'Mobile Money',
      'bank_transfer' => 'Bank Transfer',
      'cash' => 'Cash',
      'card' => 'Card',
      _ => method,
    };
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _CreditSectionLoading extends StatelessWidget {
  const _CreditSectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(width: 160, height: 20),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 104, radius: AppRadius.lg),
      ],
    );
  }
}

class _CreditSectionError extends StatelessWidget {
  const _CreditSectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('Unable to load this customer credit account.'),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
