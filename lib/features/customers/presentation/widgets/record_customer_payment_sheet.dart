import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/customer_credit_statement.dart';
import '../../domain/entities/customer_payment_request.dart';
import '../providers/customers_provider.dart';

class RecordCustomerPaymentSheet extends ConsumerStatefulWidget {
  const RecordCustomerPaymentSheet({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.outstandingSales,
  });

  final String customerId;
  final String customerName;
  final List<OutstandingCreditSale> outstandingSales;

  @override
  ConsumerState<RecordCustomerPaymentSheet> createState() =>
      _RecordCustomerPaymentSheetState();
}

class _RecordCustomerPaymentSheetState
    extends ConsumerState<RecordCustomerPaymentSheet> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<String, TextEditingController> _allocationControllers = {};

  late final List<OutstandingCreditSale> _oldestFirstSales;
  String? _paymentMethod;
  bool _isSubmitting = false;
  String? _pendingFingerprint;
  RecordCustomerPaymentRequest? _pendingRequest;

  @override
  void initState() {
    super.initState();
    _oldestFirstSales = [...widget.outstandingSales]
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));

    for (final sale in _oldestFirstSales) {
      _allocationControllers[sale.id] = TextEditingController(text: '0.00');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    for (final controller in _allocationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _totalOutstandingCents => _oldestFirstSales.fold<int>(
    0,
    (sum, sale) => sum + _toCents(sale.outstandingAmount),
  );

  int? get _amountCents => _parseCents(_amountController.text);

  int get _allocatedCents => _oldestFirstSales.fold<int>(
    0,
    (sum, sale) =>
        sum + (_parseCents(_allocationControllers[sale.id]!.text) ?? 0),
  );

  int get _remainingCents => (_amountCents ?? 0) - _allocatedCents;

  String? get _validationMessage {
    final amount = _amountCents;
    if (_amountController.text.trim().isEmpty) {
      return 'Enter a payment amount.';
    }
    if (amount == null) {
      return 'Enter an amount with no more than two decimal places.';
    }
    if (amount <= 0) {
      return 'Payment must be greater than GHS 0.00.';
    }
    if (amount > _totalOutstandingCents) {
      return "Payment cannot exceed the customer's outstanding balance.";
    }
    if (_paymentMethod == null) {
      return 'Select a payment method.';
    }

    for (final sale in _oldestFirstSales) {
      final rawAllocation = _allocationControllers[sale.id]!.text.trim();
      final allocation = _parseCents(rawAllocation);
      if (allocation == null) {
        return 'Enter valid allocations with no more than two decimal places.';
      }
      if (allocation < 0) {
        return 'Allocation cannot be negative.';
      }
      if (allocation > _toCents(sale.outstandingAmount)) {
        return 'Allocation cannot exceed ${sale.saleNumber} outstanding balance.';
      }
    }

    if (_allocatedCents != amount) {
      return 'Allocate the full payment amount before confirming.';
    }

    return null;
  }

  bool get _canConfirm => !_isSubmitting && _validationMessage == null;

  void _onAmountChanged(String value) {
    if (_oldestFirstSales.length == 1) {
      final amountCents = _parseCents(value);
      if (amountCents != null && amountCents >= 0) {
        final sale = _oldestFirstSales.single;
        final allocationCents = amountCents.clamp(
          0,
          _toCents(sale.outstandingAmount),
        );
        _allocationControllers[sale.id]!.text = _formatCents(allocationCents);
      }
    }

    setState(() {});
  }

  void _applyOldestFirst() {
    final amountCents = _amountCents;
    if (amountCents == null || amountCents <= 0) return;

    var remaining = amountCents;
    for (final sale in _oldestFirstSales) {
      final allocationCents = remaining.clamp(
        0,
        _toCents(sale.outstandingAmount),
      );
      _allocationControllers[sale.id]!.text = _formatCents(allocationCents);
      remaining -= allocationCents;
    }

    setState(() {});
  }

  RecordCustomerPaymentRequest _requestForSubmission() {
    final amountCents = _amountCents!;
    final allocations =
        _oldestFirstSales
            .map((sale) {
              return CustomerPaymentAllocation(
                saleId: sale.id,
                amount:
                    _parseCents(_allocationControllers[sale.id]!.text)! / 100,
              );
            })
            .where((allocation) => allocation.amount > 0)
            .toList(growable: false)
          ..sort((first, second) => first.saleId.compareTo(second.saleId));

    final reference = _nullableText(_referenceController.text);
    final note = _nullableText(_noteController.text);
    final fingerprint = jsonEncode([
      widget.customerId,
      amountCents,
      _paymentMethod,
      reference,
      note,
      for (final allocation in allocations)
        [allocation.saleId, _toCents(allocation.amount)],
    ]);

    if (_pendingFingerprint != fingerprint || _pendingRequest == null) {
      _pendingFingerprint = fingerprint;
      _pendingRequest = RecordCustomerPaymentRequest(
        customerId: widget.customerId,
        amount: amountCents / 100,
        paymentMethod: _paymentMethod!,
        paidAt: DateTime.now().toUtc(),
        reference: reference,
        note: note,
        idempotencyKey: _generateUuidV4(),
        allocations: List.unmodifiable(allocations),
      );
    }

    return _pendingRequest!;
  }

  Future<void> _confirmPayment() async {
    if (!_canConfirm) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(recordCustomerPaymentProvider)
          .call(_requestForSubmission());

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      _showError(_friendlyPaymentError(error));
    }
  }

  String _friendlyPaymentError(Object error) {
    final message = error is PostgrestException
        ? error.message
        : error.toString();
    final normalized = message.toLowerCase();

    if (normalized.contains('allocation exceeds outstanding')) {
      return 'A sale balance changed. Refresh the customer statement and try again.';
    }
    if (normalized.contains('allocation total must equal')) {
      return 'Allocate the full payment amount before confirming.';
    }
    if (normalized.contains('invalid payment method')) {
      return 'Select a valid payment method.';
    }
    if (normalized.contains('idempotency key')) {
      return 'This payment may already have been recorded. Refresh payment history before retrying.';
    }
    if (normalized.contains('customer') || normalized.contains('sale')) {
      return 'The customer or one of the selected sales is no longer available. Refresh and try again.';
    }

    return 'Unable to record this payment. Please try again.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String? _nullableText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  int? _parseCents(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final decimalPoint = text.indexOf('.');
    if (decimalPoint >= 0 && text.length - decimalPoint - 1 > 2) {
      return null;
    }

    final amount = double.tryParse(text);
    if (amount == null || !amount.isFinite) return null;
    return _toCents(amount);
  }

  int _toCents(double amount) => (amount * 100).round();

  String _formatCents(int cents) =>
      '${(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  String _money(double amount) => 'GHS ${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final remainingCents = _remainingCents;
    final validationMessage = _validationMessage;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Payment',
                          style: AppTypography.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.customerName,
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _amountController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(
                        labelText: 'Payment amount',
                        prefixText: 'GHS ',
                        helperText:
                            'Outstanding: ${_money(_totalOutstandingCents / 100)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Payment method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'mobile_money',
                          child: Text('Mobile Money'),
                        ),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Bank Transfer'),
                        ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                              _paymentMethod = value;
                            }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Allocate to outstanding sales',
                            style: AppTypography.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (_oldestFirstSales.length > 1)
                          TextButton(
                            onPressed: _isSubmitting ? null : _applyOldestFirst,
                            child: const Text('Apply oldest first'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final sale in _oldestFirstSales) ...[
                      _AllocationCard(
                        sale: sale,
                        controller: _allocationControllers[sale.id]!,
                        enabled: !_isSubmitting,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _AllocationTotalRow(
                      label: 'Payment amount',
                      value: _amountCents == null
                          ? _money(0)
                          : _money(_amountCents! / 100),
                    ),
                    _AllocationTotalRow(
                      label: 'Allocated',
                      value: _money(_allocatedCents / 100),
                    ),
                    _AllocationTotalRow(
                      label: 'Remaining to allocate',
                      value: _money(remainingCents / 100),
                      emphasized: remainingCents != 0,
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        validationMessage,
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _referenceController,
                      enabled: !_isSubmitting,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Reference (optional)',
                        hintText: 'MoMo transaction ID or bank reference',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _noteController,
                      enabled: !_isSubmitting,
                      minLines: 2,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canConfirm ? _confirmPayment : null,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: Text(
                    _isSubmitting ? 'Recording...' : 'Confirm Payment',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.sale,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final OutstandingCreditSale sale;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(sale.createdAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sale.saleNumber,
            style: AppTypography.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(date, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _SaleBalanceValue(label: 'Total', amount: sale.totalAmount),
              _SaleBalanceValue(label: 'Paid', amount: sale.paidAmount),
              _SaleBalanceValue(
                label: 'Outstanding',
                amount: sale.outstandingAmount,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Allocate amount',
              prefixText: 'GHS ',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleBalanceValue extends StatelessWidget {
  const _SaleBalanceValue({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: GHS ${amount.toStringAsFixed(2)}',
      style: AppTypography.textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _AllocationTotalRow extends StatelessWidget {
  const _AllocationTotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              color: emphasized ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
