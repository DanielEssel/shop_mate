import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/expense.dart';
import '../providers/expenses_provider.dart';

/// Read-only view of a single recorded expense.
class ExpenseDetailsScreen extends ConsumerWidget {
  const ExpenseDetailsScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseProvider(expenseId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Expense Details',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(expenseProvider(expenseId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: expenseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _DetailsError(
            error: error,
            onRetry: () => ref.invalidate(expenseProvider(expenseId)),
          ),
          data: (expense) => _DetailsBody(expense: expense),
        ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final createdAt = expense.createdAt.toLocal();
    final recorded =
        '${localizations.formatMediumDate(createdAt)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(createdAt))}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.category.label,
                        style: AppTypography.textTheme.bodyMedium!.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatGhs(expense.amount),
                        style: AppTypography.textTheme.headlineSmall!.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Category',
                        value: expense.category.label,
                      ),
                      _DetailRow(
                        label: 'Amount',
                        value: formatGhs(expense.amount),
                      ),
                      _DetailRow(
                        label: 'Payment method',
                        value: expense.paymentMethod.label,
                      ),
                      _DetailRow(
                        label: 'Expense date',
                        value: localizations.formatMediumDate(
                          expense.expenseDate,
                        ),
                      ),
                      _DetailRow(label: 'Reference', value: expense.reference),
                      _DetailRow(label: 'Note', value: expense.note),
                      _DetailRow(label: 'Recorded', value: recorded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;

  /// Shown as an em dash when absent.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SelectableText(
              text ?? '—',
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: text == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final detail = error is PostgrestException
        ? (error as PostgrestException).message
        : error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load this expense',
              style: AppTypography.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodySmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
