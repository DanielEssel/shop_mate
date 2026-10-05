import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_filter.dart';
import '../../domain/entities/expense_history.dart';
import '../../domain/usecases/get_expense_history.dart';
import '../providers/expenses_provider.dart';
import '../widgets/expense_filters.dart';
import '../widgets/record_expense_form.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(expenseHistoryProvider);
    await ref.read(expenseHistoryProvider.future);
  }

  Future<void> _recordExpense(BuildContext context, WidgetRef ref) async {
    final wasRecorded = await showRecordExpenseForm(context);

    if (!wasRecorded || !context.mounted) return;

    ref.invalidate(expenseHistoryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense recorded.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(expenseHistoryProvider);
    final filter = ref.watch(expenseFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Expenses',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses_fab',
        onPressed: () => _recordExpense(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Expense'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? AppSpacing.xl : AppSpacing.md,
                  isDesktop ? AppSpacing.lg : AppSpacing.sm,
                  isDesktop ? AppSpacing.xl : AppSpacing.md,
                  110,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Operating costs such as rent, utilities and '
                            'transport recorded for your shop.',
                            style: AppTypography.textTheme.bodyMedium!.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const ExpenseFilters(),
                          const SizedBox(height: AppSpacing.lg),
                          historyAsync.when(
                            loading: () => const _HistoryLoading(),
                            error: (error, _) => _HistoryError(
                              error: error,
                              onRetry: () => _refresh(ref),
                            ),
                            data: (history) => _HistoryBody(
                              history: history,
                              filter: filter,
                              onClearFilters: () => ref
                                  .read(expenseFilterProvider.notifier)
                                  .clear(),
                              onRecordExpense: () =>
                                  _recordExpense(context, ref),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.history,
    required this.filter,
    required this.onClearFilters,
    required this.onRecordExpense,
  });

  final ExpenseHistory history;
  final ExpenseFilter filter;
  final VoidCallback onClearFilters;
  final VoidCallback onRecordExpense;

  @override
  Widget build(BuildContext context) {
    if (history.expenses.isEmpty) {
      return _EmptyState(
        hasFilters: !filter.isEmpty,
        onClearFilters: onClearFilters,
        onRecordExpense: onRecordExpense,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalSummary(history: history, isFiltered: !filter.isEmpty),
        if (history.hasMore) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Showing the ${GetExpenseHistory.maxResults} most recent matching '
            'expenses. Narrow the date range to see older expenses; the total '
            'covers the expenses shown.',
            style: AppTypography.textTheme.bodySmall!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final expense in history.expenses) ...[
          _ExpenseTile(
            expense: expense,
            onTap: () => context.push('/expenses/${expense.id}'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _TotalSummary extends StatelessWidget {
  const _TotalSummary({required this.history, required this.isFiltered});

  final ExpenseHistory history;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final count = history.expenses.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.xs,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFiltered ? 'Total for selected filters' : 'Total expenses',
                style: AppTypography.textTheme.bodySmall!.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatGhs(history.totalAmount),
                style: AppTypography.textTheme.headlineSmall!.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            '$count ${count == 1 ? 'expense' : 'expenses'}',
            style: AppTypography.textTheme.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(expense.expenseDate);
    final reference = expense.reference;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.category.label,
                      style: AppTypography.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$date · ${expense.paymentMethod.label}',
                      style: AppTypography.textTheme.bodySmall!.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (reference != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: $reference',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.textTheme.bodySmall!.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                formatGhs(expense.amount),
                style: AppTypography.textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.section),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.onClearFilters,
    required this.onRecordExpense,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onRecordExpense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.section,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 44,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasFilters ? 'No matching expenses' : 'No expenses yet',
            style: AppTypography.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasFilters
                ? 'No expenses match the current filters.'
                : 'Expenses you record will appear here.',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasFilters)
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear Filters'),
            )
          else
            FilledButton.icon(
              onPressed: onRecordExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record Expense'),
            ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final detail = error is PostgrestException
        ? (error as PostgrestException).message
        : error.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.section,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Unable to load expenses',
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
    );
  }
}
