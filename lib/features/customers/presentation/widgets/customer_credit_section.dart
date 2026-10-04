import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/customer_credit_statement.dart';
import '../providers/customers_provider.dart';
import 'customer_summary_card.dart';
import 'record_customer_payment_sheet.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credit Account',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final spacing = AppSpacing.md;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: CustomerSummaryCard(
                    title: 'Credit sales',
                    value: _money(statement.totalCreditSales),
                    subtitle: 'Total credit sale value',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: CustomerSummaryCard(
                    title: 'Paid',
                    value: _money(statement.totalPaid),
                    subtitle: 'Allocated payments',
                    icon: Icons.payments_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: CustomerSummaryCard(
                    title: 'Outstanding',
                    value: _money(statement.outstandingBalance),
                    subtitle: 'Current balance due',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: CustomerSummaryCard(
                    title: 'Open credit sales',
                    value: statement.outstandingSaleCount.toString(),
                    subtitle: 'Sales with an outstanding balance',
                    icon: Icons.pending_actions_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: statement.outstandingSales.isEmpty
                ? null
                : () => _recordPayment(context, ref),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record Payment'),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _SectionHeading(title: 'Outstanding Credit Sales'),
        const SizedBox(height: AppSpacing.sm),
        if (statement.totalCreditSales == 0)
          const _SectionEmptyState(
            message: 'No credit sales for this customer yet.',
          )
        else if (statement.outstandingSales.isEmpty)
          const _SectionEmptyState(message: 'No outstanding credit sales.')
        else
          for (final sale in statement.outstandingSales) ...[
            _OutstandingSaleCard(sale: sale),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.lg),
        _SectionHeading(title: 'Payment History'),
        const SizedBox(height: AppSpacing.sm),
        if (statement.paymentHistory.isEmpty)
          const _SectionEmptyState(message: 'No payments recorded yet.')
        else
          for (final payment in statement.paymentHistory) ...[
            _PaymentHistoryCard(payment: payment),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  String _money(double value) => 'GHS ${value.toStringAsFixed(2)}';
}

class _OutstandingSaleCard extends StatelessWidget {
  const _OutstandingSaleCard({required this.sale});

  final OutstandingCreditSale sale;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(sale.createdAt.toLocal());

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => context.push('/sales/${sale.id}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sale.saleNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                date,
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.xs,
                children: [
                  _CompactAmount(label: 'Total', amount: sale.totalAmount),
                  _CompactAmount(label: 'Paid', amount: sale.paidAmount),
                  _CompactAmount(
                    label: 'Outstanding',
                    amount: sale.outstandingAmount,
                    emphasized: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment});

  final CustomerPaymentHistoryEntry payment;

  @override
  Widget build(BuildContext context) {
    final localDate = payment.paidAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(localDate);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(localDate));
    final reference = payment.reference?.trim();
    final note = payment.note?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _paymentMethodLabel(payment.paymentMethod),
                  style: AppTypography.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _money(payment.amount),
                style: AppTypography.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$date · $time',
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (reference != null && reference.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Reference: $reference'),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Note: $note'),
          ],
          if (payment.allocatedSaleNumbers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Allocated to ${payment.allocatedSaleNumbers.join(', ')}',
              style: AppTypography.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
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

  String _money(double value) => 'GHS ${value.toStringAsFixed(2)}';
}

class _CompactAmount extends StatelessWidget {
  const _CompactAmount({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTypography.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: 'GHS ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.textTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        message,
        style: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CreditSectionLoading extends StatelessWidget {
  const _CreditSectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _CreditSectionError extends StatelessWidget {
  const _CreditSectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionEmptyStateWithRetry(onRetry: onRetry);
  }
}

class _SectionEmptyStateWithRetry extends StatelessWidget {
  const _SectionEmptyStateWithRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unable to load this customer credit account.'),
          const SizedBox(height: AppSpacing.sm),
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
