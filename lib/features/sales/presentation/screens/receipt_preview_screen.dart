import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../customers/presentation/providers/customers_provider.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../providers/sales_provider.dart';
import '../services/receipt_output_service.dart';

class ReceiptPreviewScreen extends ConsumerWidget {
  const ReceiptPreviewScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleProvider(saleId));
    final itemsAsync = ref.watch(saleItemsProvider(saleId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Receipt Preview')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: saleAsync.when(
                loading: () => const _ReceiptLoading(),
                error: (_, _) => _ReceiptError(
                  onRetry: () {
                    ref.invalidate(saleProvider(saleId));
                    ref.invalidate(saleItemsProvider(saleId));
                  },
                ),
                data: (sale) => itemsAsync.when(
                  loading: () => const _ReceiptLoading(),
                  error: (_, _) => _ReceiptError(
                    onRetry: () {
                      ref.invalidate(saleItemsProvider(saleId));
                    },
                  ),
                  data: (items) =>
                      _ReceiptCustomerContent(sale: sale, items: items),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptCustomerContent extends ConsumerWidget {
  const _ReceiptCustomerContent({required this.sale, required this.items});

  final Sale sale;
  final List<SaleItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopName = ref.watch(shopAccessProvider).value?.shopName;
    final customerId = sale.customerId;

    if (customerId == null) {
      return _ReceiptPaymentContent(
        sale: sale,
        items: items,
        shopName: shopName,
      );
    }

    final customerAsync = ref.watch(customerProvider(customerId));

    return customerAsync.when(
      loading: () => const _ReceiptLoading(),
      error: (_, _) => _ReceiptError(
        onRetry: () {
          ref.invalidate(customerProvider(customerId));
        },
      ),
      data: (customer) => _ReceiptPaymentContent(
        sale: sale,
        items: items,
        shopName: shopName,
        customerName: customer.name,
      ),
    );
  }
}

class _ReceiptPaymentContent extends ConsumerWidget {
  const _ReceiptPaymentContent({
    required this.sale,
    required this.items,
    required this.shopName,
    this.customerName,
  });

  final Sale sale;
  final List<SaleItem> items;
  final String? shopName;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!sale.isCredit) {
      return _ReceiptDocument(
        sale: sale,
        items: items,
        shopName: shopName,
        customerName: customerName,
        paidAmount: sale.amountPaid,
        paymentMethod: sale.paymentMethodLabel,
      );
    }

    final summaryAsync = ref.watch(salePaymentSummaryProvider(sale.id));

    return summaryAsync.when(
      loading: () => const _ReceiptLoading(),
      error: (_, _) => _ReceiptError(
        onRetry: () {
          ref.invalidate(salePaymentSummaryProvider(sale.id));
        },
      ),
      data: (summary) => _ReceiptDocument(
        sale: sale,
        items: items,
        shopName: shopName,
        customerName: customerName,
        paidAmount: summary.paidAmount,
        paymentMethod: summary.paymentMethods
            .map(_paymentMethodLabel)
            .toSet()
            .join(', '),
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
}

class _ReceiptDocument extends StatefulWidget {
  const _ReceiptDocument({
    required this.sale,
    required this.items,
    required this.shopName,
    required this.paidAmount,
    required this.paymentMethod,
    this.customerName,
  });

  final Sale sale;
  final List<SaleItem> items;
  final String? shopName;
  final String? customerName;
  final double paidAmount;
  final String paymentMethod;

  @override
  State<_ReceiptDocument> createState() => _ReceiptDocumentState();
}

class _ReceiptDocumentState extends State<_ReceiptDocument> {
  final _outputService = ReceiptOutputService();

  Uint8List? _pdfBytes;
  String? _busyAction;

  @override
  void didUpdateWidget(covariant _ReceiptDocument oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_hasSamePdfData(oldWidget)) {
      _pdfBytes = null;
    }
  }

  bool _hasSamePdfData(_ReceiptDocument other) {
    return other.sale.id == widget.sale.id &&
        other.sale.saleNumber == widget.sale.saleNumber &&
        other.sale.totalAmount == widget.sale.totalAmount &&
        other.sale.changeAmount == widget.sale.changeAmount &&
        other.sale.isCredit == widget.sale.isCredit &&
        other.sale.createdAt == widget.sale.createdAt &&
        other.items.length == widget.items.length &&
        _itemsHaveSamePdfData(other.items, widget.items) &&
        other.shopName == widget.shopName &&
        other.customerName == widget.customerName &&
        other.paidAmount == widget.paidAmount &&
        other.paymentMethod == widget.paymentMethod;
  }

  bool _itemsHaveSamePdfData(List<SaleItem> first, List<SaleItem> second) {
    for (var index = 0; index < first.length; index++) {
      final firstItem = first[index];
      final secondItem = second[index];

      if (firstItem.id != secondItem.id ||
          firstItem.productName != secondItem.productName ||
          firstItem.quantity != secondItem.quantity ||
          firstItem.unitPrice != secondItem.unitPrice ||
          firstItem.subtotal != secondItem.subtotal) {
        return false;
      }
    }

    return true;
  }

  Future<Uint8List> _getPdfBytes() async {
    final cachedBytes = _pdfBytes;
    if (cachedBytes != null) return cachedBytes;

    final localCreatedAt = widget.sale.createdAt.toLocal();
    final bytes = await _outputService.generatePdf(
      ReceiptPdfData(
        sale: widget.sale,
        items: widget.items,
        shopName: widget.shopName,
        customerName: widget.customerName,
        paidAmount: widget.paidAmount,
        paymentMethod: widget.sale.isCredit && widget.paymentMethod.isEmpty
            ? 'Credit'
            : widget.paymentMethod,
        date: MaterialLocalizations.of(
          context,
        ).formatMediumDate(localCreatedAt),
        time: MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(TimeOfDay.fromDateTime(localCreatedAt)),
      ),
    );

    _pdfBytes = bytes;
    return bytes;
  }

  Future<void> _sharePdf() async {
    if (_busyAction != null) return;

    setState(() {
      _busyAction = 'share';
    });

    try {
      final capabilities = await _outputService.capabilities();
      if (!capabilities.canShare) {
        _showMessage('PDF sharing is not available on this platform.');
        return;
      }

      final bytes = await _getPdfBytes();
      final shared = await _outputService.sharePdf(
        bytes: bytes,
        filename: _outputService.filenameFor(widget.sale.saleNumber),
      );

      _showMessage(
        shared ? 'PDF is ready to share or save.' : 'Sharing was cancelled.',
      );
    } catch (_) {
      _showMessage('Unable to create or share the PDF. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _printPdf() async {
    if (_busyAction != null) return;

    setState(() {
      _busyAction = 'print';
    });

    try {
      final capabilities = await _outputService.capabilities();
      if (!capabilities.canPrint) {
        _showMessage('Printing is not available on this platform.');
        return;
      }

      final bytes = await _getPdfBytes();
      final printed = await _outputService.printPdf(
        bytes: bytes,
        filename: _outputService.filenameFor(widget.sale.saleNumber),
      );

      _showMessage(
        printed
            ? 'Receipt sent to the print service.'
            : 'Printing was cancelled.',
      );
    } catch (_) {
      _showMessage('Unable to print this receipt. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final items = widget.items;
    final localCreatedAt = sale.createdAt.toLocal();
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(localCreatedAt);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(localCreatedAt));
    final subtotal = items.fold<double>(
      0,
      (total, item) => total + item.subtotal,
    );
    final outstanding = (sale.totalAmount - widget.paidAmount)
        .clamp(0.0, double.infinity)
        .toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = constraints.maxWidth < 480
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _shareButton(),
                  const SizedBox(height: AppSpacing.sm),
                  _printButton(),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _shareButton()),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _printButton()),
                ],
              );

        return SingleChildScrollView(
          child: Column(
            children: [
              actions,
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.shopName != null &&
                        widget.shopName!.trim().isNotEmpty) ...[
                      Text(
                        widget.shopName!,
                        textAlign: TextAlign.center,
                        style: AppTypography.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      'SALES RECEIPT',
                      textAlign: TextAlign.center,
                      style: AppTypography.textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      sale.saleNumber,
                      textAlign: TextAlign.center,
                      style: AppTypography.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptLabelValueRow(label: 'Date', value: date),
                    _ReceiptLabelValueRow(label: 'Time', value: time),
                    if (widget.customerName != null)
                      _ReceiptLabelValueRow(
                        label: 'Customer',
                        value: widget.customerName!,
                      ),
                    if (sale.isCredit) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'CREDIT',
                            style: AppTypography.textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Divider(),
                    ),
                    const _ReceiptItemsHeader(),
                    const SizedBox(height: AppSpacing.sm),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(
                          'No sale items found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      for (var index = 0; index < items.length; index++) ...[
                        _ReceiptItemRow(item: items[index]),
                        if (index < items.length - 1)
                          const Divider(height: AppSpacing.lg),
                      ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Divider(),
                    ),
                    _ReceiptAmountRow(label: 'Subtotal', amount: subtotal),
                    const SizedBox(height: AppSpacing.xs),
                    _ReceiptAmountRow(
                      label: 'Total',
                      amount: sale.totalAmount,
                      emphasized: true,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ReceiptAmountRow(label: 'Paid', amount: widget.paidAmount),
                    if (sale.isCredit)
                      _ReceiptAmountRow(
                        label: 'Outstanding',
                        amount: outstanding,
                        emphasized: outstanding > 0,
                      )
                    else if (sale.changeAmount > 0)
                      _ReceiptAmountRow(
                        label: 'Change',
                        amount: sale.changeAmount,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    if (sale.isCredit)
                      _ReceiptLabelValueRow(
                        label: 'Payment',
                        value: widget.paymentMethod.isEmpty
                            ? 'Credit'
                            : widget.paymentMethod,
                      )
                    else
                      _ReceiptLabelValueRow(
                        label: 'Payment',
                        value: sale.paymentMethodLabel,
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'Thank you for your business',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shareButton() {
    final isBusy = _busyAction != null;

    return FilledButton.icon(
      onPressed: isBusy ? null : _sharePdf,
      icon: _busyAction == 'share'
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_outlined),
      label: const Text('Share / Save PDF'),
    );
  }

  Widget _printButton() {
    final isBusy = _busyAction != null;

    return OutlinedButton.icon(
      onPressed: isBusy ? null : _printPdf,
      icon: _busyAction == 'print'
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined),
      label: const Text('Print'),
    );
  }
}

class _ReceiptItemsHeader extends StatelessWidget {
  const _ReceiptItemsHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Items',
      style: AppTypography.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ReceiptItemRow extends StatelessWidget {
  const _ReceiptItemRow({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity} × GHS ${item.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    'GHS ${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text('${item.quantity}', textAlign: TextAlign.center),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'GHS ${item.unitPrice.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: Text(
                'GHS ${item.subtotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReceiptAmountRow extends StatelessWidget {
  const _ReceiptAmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.textTheme.bodyLarge?.copyWith(
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
      color: emphasized ? AppColors.textPrimary : AppColors.textSecondary,
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('GHS ${amount.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}

class _ReceiptLabelValueRow extends StatelessWidget {
  const _ReceiptLabelValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLoading extends StatelessWidget {
  const _ReceiptLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ReceiptError extends StatelessWidget {
  const _ReceiptError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Receipt unavailable',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'We could not load this receipt. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
