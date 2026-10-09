import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
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
    final isCompact = Breakpoints.ofWindow(context).isCompact;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Phones get the thumb-reachable button; wider layouts put it in the
      // page header.
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              heroTag: 'expenses_fab',
              onPressed: () => _recordExpense(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record Expense'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = Breakpoints.pagePadding(
              constraints.maxWidth,
              maxWidth: ContentWidth.wide,
            );

            Widget boxed(Widget child) {
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  0,
                  horizontal,
                  AppSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(child: child),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      isCompact ? AppSpacing.md : AppSpacing.xxl,
                      horizontal,
                      AppSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: PageHeader(
                        title: 'Expenses',
                        subtitle:
                            'Operating costs such as rent, utilities and '
                            'transport',
                        leading: pageHeaderLeading(context),
                        actions: [
                          if (!isCompact)
                            PrimaryButton(
                              label: 'Record Expense',
                              icon: Icons.add_rounded,
                              onPressed: () => _recordExpense(context, ref),
                            ),
                        ],
                      ),
                    ),
                  ),
                  boxed(
                    isCompact
                        ? _CollapsibleFilters(filter: filter)
                        : const ExpenseFilters(),
                  ),
                  ...historyAsync.when(
                    loading: () => [boxed(const SkeletonList(rows: 5))],
                    error: (error, _) => [
                      boxed(
                        SurfaceCard(
                          child: ErrorState(
                            compact: true,
                            title: 'Unable to load expenses',
                            message: 'Check your connection and try again.',
                            onRetry: () => _refresh(ref),
                          ),
                        ),
                      ),
                    ],
                    data: (history) => _historySlivers(
                      context,
                      history: history,
                      isFiltered: !filter.isEmpty,
                      horizontal: horizontal,
                      bottom: isCompact ? 96 : AppSpacing.xxxl,
                      onClearFilters: () =>
                          ref.read(expenseFilterProvider.notifier).clear(),
                      onRecordExpense: () => _recordExpense(context, ref),
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

  List<Widget> _historySlivers(
    BuildContext context, {
    required ExpenseHistory history,
    required bool isFiltered,
    required double horizontal,
    required double bottom,
    required VoidCallback onClearFilters,
    required VoidCallback onRecordExpense,
  }) {
    final expenses = history.expenses;

    if (expenses.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottom),
          sliver: SliverToBoxAdapter(
            child: SurfaceCard(
              child: isFiltered
                  ? EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No matching expenses',
                      message: 'No expenses match the current filters.',
                      actionLabel: 'Clear Filters',
                      actionIcon: Icons.filter_alt_off_outlined,
                      onAction: onClearFilters,
                    )
                  : EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No expenses yet',
                      message: 'Expenses you record will appear here.',
                      actionLabel: 'Record Expense',
                      onAction: onRecordExpense,
                    ),
            ),
          ),
        ),
      ];
    }

    final count = expenses.length;
    final byCategory = <ExpenseCategory, double>{};
    for (final expense in expenses) {
      byCategory.update(
        expense.category,
        (total) => total + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final top = byCategory.entries.reduce((a, b) => a.value >= b.value ? a : b);

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          AppSpacing.sm,
          horizontal,
          history.hasMore ? AppSpacing.sm : AppSpacing.xxl,
        ),
        sliver: SliverToBoxAdapter(
          child: MetricGrid(
            cards: [
              MetricCard(
                label: isFiltered ? 'Total for Filters' : 'Total Expenses',
                value: formatGhs(history.totalAmount),
                caption: '$count ${count == 1 ? 'expense' : 'expenses'}',
                icon: Icons.account_balance_wallet_outlined,
                emphasized: true,
              ),
              MetricCard(
                label: 'Average',
                value: formatGhs(history.totalAmount / count),
                caption: 'Per expense',
                icon: Icons.functions_rounded,
                tone: StatusTone.info,
              ),
              MetricCard(
                label: 'Largest Category',
                value: top.key.label,
                caption: formatGhs(top.value),
                icon: Icons.category_outlined,
                tone: StatusTone.warning,
              ),
            ],
          ),
        ),
      ),
      if (history.hasMore)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            0,
            horizontal,
            AppSpacing.xxl,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Showing the ${GetExpenseHistory.maxResults} most recent '
              'matching expenses. Narrow the date range to see older '
              'expenses; the total covers the expenses shown.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottom),
        sliver: SliverAdaptiveDataTable<Expense>(
          rows: expenses,
          onRowTap: (expense) => _open(context, expense),
          compactRowBuilder: (context, expense) => TransactionRow(
            reference: expense.category.label,
            details: [
              expense.paymentMethod.label,
              formatShortDate(expense.expenseDate),
              if (expense.reference case final reference?) 'Ref: $reference',
            ],
            amount: formatGhs(expense.amount),
            icon: Icons.receipt_outlined,
            onTap: () => _open(context, expense),
          ),
          columns: _columns,
        ),
      ),
    ];
  }

  static void _open(BuildContext context, Expense expense) {
    context.push('/expenses/${expense.id}');
  }

  static final List<DataColumnSpec<Expense>> _columns = [
    DataColumnSpec<Expense>(
      label: 'Category',
      flex: 3,
      compare: (a, b) => a.category.label.compareTo(b.category.label),
      cell: (expense) => Text(
        expense.category.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    DataColumnSpec<Expense>(
      label: 'Date',
      flex: 2,
      compare: (a, b) => a.expenseDate.compareTo(b.expenseDate),
      cell: (expense) => Text(
        formatShortDate(expense.expenseDate),
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Expense>(
      label: 'Payment',
      flex: 2,
      cell: (expense) => Text(
        expense.paymentMethod.label,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
    DataColumnSpec<Expense>(
      label: 'Reference',
      flex: 2,
      visibleFrom: WindowSize.expanded,
      cell: (expense) => Text(
        expense.reference ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textMuted),
      ),
    ),
    DataColumnSpec<Expense>(
      label: 'Amount',
      flex: 2,
      numeric: true,
      compare: (a, b) => a.amount.compareTo(b.amount),
      cell: (expense) =>
          Text(formatGhs(expense.amount), style: AppTypography.amount),
    ),
  ];
}

/// Phones: the filter panel folds behind one row so the figures and list
/// stay near the top. Shows how many filters are on.
class _CollapsibleFilters extends StatefulWidget {
  const _CollapsibleFilters({required this.filter});

  final ExpenseFilter filter;

  @override
  State<_CollapsibleFilters> createState() => _CollapsibleFiltersState();
}

class _CollapsibleFiltersState extends State<_CollapsibleFilters> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final active = [
      filter.dateFrom,
      filter.dateTo,
      filter.category,
      filter.paymentMethod,
    ].where((value) => value != null).length;

    final toggle = SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Row(
        children: [
          const Icon(
            Icons.tune_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (active > 0) ...[
            StatusBadge(
              label: '$active on',
              tone: StatusTone.brand,
              showDot: false,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Icon(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );

    return Semantics(
      expanded: _expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toggle,
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            const ExpenseFilters(),
          ],
        ],
      ),
    );
  }
}
