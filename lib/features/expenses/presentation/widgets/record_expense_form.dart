import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/uuid_v4.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_payment_method.dart';
import '../../domain/entities/record_expense_request.dart';
import '../providers/expenses_provider.dart';

/// Opens the Record Expense form as a centered dialog on wide (desktop)
/// layouts and as a modal bottom sheet on phones.
///
/// Returns `true` when an expense was recorded.
Future<bool> showRecordExpenseForm(BuildContext context) async {
  final isDesktop = MediaQuery.sizeOf(context).width >= 900;

  final bool? wasRecorded;
  if (isDesktop) {
    wasRecorded = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.92,
            ),
            child: const RecordExpenseForm(),
          ),
        );
      },
    );
  } else {
    wasRecorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        // Lift the form above the keyboard; the field list scrolls inside.
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
            ),
            child: const RecordExpenseForm(),
          ),
        );
      },
    );
  }

  return wasRecorded == true;
}

class RecordExpenseForm extends ConsumerStatefulWidget {
  const RecordExpenseForm({super.key});

  @override
  ConsumerState<RecordExpenseForm> createState() => _RecordExpenseFormState();
}

class _RecordExpenseFormState extends ConsumerState<RecordExpenseForm> {
  /// Matches the `record_expense` upper bound (amount < 10,000,000,000).
  static const _maxAmountCents = 1000000000000;

  static final _plainAmount = RegExp(r'^\d+(\.\d{1,2})?$');
  static final _groupedAmount = RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})?$');
  static final _tooManyDecimals = RegExp(r'^[\d,]*\.\d{3,}$');

  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  late final DateTime _today = _dateOnly(DateTime.now());
  late DateTime _expenseDate = _today;
  ExpenseCategory? _category;
  ExpensePaymentMethod? _paymentMethod;

  bool _isSubmitting = false;
  String? _submitError;
  String? _pendingFingerprint;
  RecordExpenseRequest? _pendingRequest;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? get _amountCents => _parseCents(_amountController.text);

  /// Inline error for the amount field; null while empty or valid.
  String? get _amountError {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('-')) {
      return 'Amount must be greater than GHS 0.00.';
    }
    if (_tooManyDecimals.hasMatch(text)) {
      return 'Use no more than two decimal places.';
    }

    final cents = _amountCents;
    if (cents == null) {
      return 'Enter a valid amount, e.g. 1000 or 1,000.50.';
    }
    if (cents <= 0) {
      return 'Amount must be greater than GHS 0.00.';
    }
    if (cents >= _maxAmountCents) {
      return 'Amount is too large.';
    }

    return null;
  }

  bool get _isDateValid =>
      !_expenseDate.isAfter(_today) && !_expenseDate.isBefore(DateTime(2020));

  String? get _validationMessage {
    if (_category == null) return 'Select a category.';
    if (_amountController.text.trim().isEmpty) {
      return 'Enter an expense amount.';
    }
    if (_amountError case final error?) return error;
    if (_paymentMethod == null) return 'Select a payment method.';
    if (!_isDateValid) return 'Select a valid expense date.';

    return null;
  }

  bool get _canConfirm => !_isSubmitting && _validationMessage == null;

  void _onChanged() {
    setState(() {
      _submitError = null;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: _today,
    );

    if (selected == null || !mounted) return;

    setState(() {
      _expenseDate = _dateOnly(selected);
      _submitError = null;
    });
  }

  /// Reuses the pending request (and its idempotency key) while the entered
  /// data is unchanged, so retrying a failed submission cannot create a
  /// duplicate. Any change to the data produces a new key.
  RecordExpenseRequest _requestForSubmission() {
    final amountCents = _amountCents!;
    final reference = _nullableText(_referenceController.text);
    final note = _nullableText(_noteController.text);
    final fingerprint = jsonEncode([
      _category!.code,
      amountCents,
      _paymentMethod!.code,
      _expenseDate.toIso8601String(),
      reference,
      note,
    ]);

    if (_pendingFingerprint != fingerprint || _pendingRequest == null) {
      _pendingFingerprint = fingerprint;
      _pendingRequest = RecordExpenseRequest(
        category: _category!,
        amount: amountCents / 100,
        paymentMethod: _paymentMethod!,
        expenseDate: _expenseDate,
        reference: reference,
        note: note,
        idempotencyKey: generateUuidV4(),
      );
    }

    return _pendingRequest!;
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await ref.read(recordExpenseProvider).call(_requestForSubmission());

      // The key belongs to the expense that was just recorded.
      _pendingFingerprint = null;
      _pendingRequest = null;

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'The request timed out. Check your connection and try again; '
          'retrying will not record this expense twice.';
    }
    if (error is! PostgrestException) {
      return 'Unable to reach ShopMate. Check your connection and try again; '
          'retrying will not record this expense twice.';
    }

    final normalized = error.message.toLowerCase();

    if (normalized.contains('authentication is required')) {
      return 'Your session has expired. Sign in again to record expenses.';
    }
    if (normalized.contains('no active shop')) {
      return 'Your account has no active shop. Expenses cannot be recorded.';
    }
    if (normalized.contains('invalid expense category')) {
      return 'Select a valid expense category.';
    }
    if (normalized.contains('invalid payment method')) {
      return 'Select a valid payment method.';
    }
    if (normalized.contains('expense amount')) {
      return 'Enter an amount greater than GHS 0.00 with at most two decimal places.';
    }
    if (normalized.contains('expense date')) {
      return 'Select a valid expense date.';
    }
    if (normalized.contains('idempotency key')) {
      return 'This request was already used for a different expense. '
          'Close the form and check before recording again.';
    }

    return 'Unable to record this expense: ${error.message}';
  }

  String? _nullableText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// Parses a GHS amount into cents without floating-point rounding.
  /// Returns null for anything that is not a non-negative amount with at
  /// most two decimal places (optionally with correct thousands separators).
  int? _parseCents(String value) {
    final text = value.trim();
    if (!_plainAmount.hasMatch(text) && !_groupedAmount.hasMatch(text)) {
      return null;
    }

    final parts = text.replaceAll(',', '').split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null || parts[0].length > 12) return null;

    final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';

    return whole * 100 + int.parse(fraction);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Widget build(BuildContext context) {
    final validationMessage = _validationMessage;
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(_expenseDate);

    return PopScope(
      canPop: !_isSubmitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Expense',
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Rent, utilities, transport and other operating costs.',
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final category in ExpenseCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            _category = value;
                            _onChanged();
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _amountController,
                    enabled: !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _onChanged(),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'GHS ',
                      hintText: '0.00',
                      errorText: _amountError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ExpensePaymentMethod>(
                    initialValue: _paymentMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final method in ExpensePaymentMethod.values)
                        DropdownMenuItem(
                          value: method,
                          child: Text(method.label),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            _paymentMethod = value;
                            _onChanged();
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: _isSubmitting ? null : _pickDate,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: InputDecorator(
                      isEmpty: false,
                      decoration: InputDecoration(
                        labelText: 'Expense date',
                        enabled: !_isSubmitting,
                        errorText: _isDateValid
                            ? null
                            : 'Select a valid expense date.',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(dateLabel),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _referenceController,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Reference (optional)',
                      hintText: 'Receipt, invoice or transaction number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _noteController,
                    enabled: !_isSubmitting,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_submitError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SubmitErrorBanner(message: _submitError!),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (validationMessage != null && !_isSubmitting) ...[
                  Text(
                    validationMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                FilledButton.icon(
                  onPressed: _canConfirm ? _confirm : null,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isSubmitting
                        ? 'Recording...'
                        : _submitError != null
                        ? 'Retry'
                        : 'Record Expense',
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

class _SubmitErrorBanner extends StatelessWidget {
  const _SubmitErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
