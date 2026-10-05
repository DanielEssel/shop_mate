import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_payment_method.dart';
import '../providers/expenses_provider.dart';

/// Date range, category and payment method filters for expense history.
/// Each change applies immediately and reloads the history.
class ExpenseFilters extends ConsumerWidget {
  const ExpenseFilters({super.key});

  /// Earliest selectable date, matching the Record Expense form.
  static final _firstDate = DateTime(2020);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickFrom(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(expenseFilterProvider);
    // "From" can never be later than "To" or today.
    final lastDate = filter.dateTo ?? _today();

    final selected = await showDatePicker(
      context: context,
      initialDate: filter.dateFrom ?? lastDate,
      firstDate: _firstDate,
      lastDate: lastDate,
      helpText: 'Expenses from',
    );

    if (selected == null) return;

    final current = ref.read(expenseFilterProvider);
    ref
        .read(expenseFilterProvider.notifier)
        .setDateRange(from: selected, to: current.dateTo);
  }

  Future<void> _pickTo(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(expenseFilterProvider);
    // "To" can never be earlier than "From" or later than today.
    final firstDate = filter.dateFrom ?? _firstDate;

    final selected = await showDatePicker(
      context: context,
      initialDate: filter.dateTo ?? _today(),
      firstDate: firstDate,
      lastDate: _today(),
      helpText: 'Expenses to',
    );

    if (selected == null) return;

    final current = ref.read(expenseFilterProvider);
    ref
        .read(expenseFilterProvider.notifier)
        .setDateRange(from: current.dateFrom, to: selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(expenseFilterProvider);
    final notifier = ref.read(expenseFilterProvider.notifier);
    final localizations = MaterialLocalizations.of(context);

    final fromField = _DateFilterField(
      label: 'From',
      value: filter.dateFrom == null
          ? null
          : localizations.formatMediumDate(filter.dateFrom!),
      onTap: () => _pickFrom(context, ref),
      onClear: () => notifier.setDateRange(from: null, to: filter.dateTo),
    );

    final toField = _DateFilterField(
      label: 'To',
      value: filter.dateTo == null
          ? null
          : localizations.formatMediumDate(filter.dateTo!),
      onTap: () => _pickTo(context, ref),
      onClear: () => notifier.setDateRange(from: filter.dateFrom, to: null),
    );

    // Keyed by value so the field resets when filters are cleared.
    final categoryField = DropdownButtonFormField<ExpenseCategory?>(
      key: ValueKey(filter.category),
      initialValue: filter.category,
      isExpanded: true,
      decoration: _decoration('Category'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All')),
        for (final category in ExpenseCategory.values)
          DropdownMenuItem(value: category, child: Text(category.label)),
      ],
      onChanged: notifier.setCategory,
    );

    final methodField = DropdownButtonFormField<ExpensePaymentMethod?>(
      key: ValueKey(filter.paymentMethod),
      initialValue: filter.paymentMethod,
      isExpanded: true,
      decoration: _decoration('Payment method'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All')),
        for (final method in ExpensePaymentMethod.values)
          DropdownMenuItem(value: method, child: Text(method.label)),
      ],
      onChanged: notifier.setPaymentMethod,
    );

    final clearButton = TextButton.icon(
      onPressed: filter.isEmpty ? null : notifier.clear,
      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
      label: const Text('Clear filters'),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                Expanded(child: fromField),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: toField),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: categoryField),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: methodField),
                const SizedBox(width: AppSpacing.sm),
                clearButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: fromField),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: toField),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              categoryField,
              const SizedBox(height: AppSpacing.sm),
              methodField,
              Align(alignment: Alignment.centerRight, child: clearButton),
            ],
          );
        },
      ),
    );
  }

  static InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        isEmpty: false,
        decoration: ExpenseFilters._decoration(label).copyWith(
          suffixIcon: hasValue
              ? IconButton(
                  tooltip: 'Clear $label date',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value ?? 'Any date',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasValue ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
