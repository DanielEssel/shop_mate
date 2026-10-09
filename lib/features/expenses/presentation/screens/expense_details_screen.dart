import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
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
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontal = Breakpoints.pagePadding(
              width,
              maxWidth: ContentWidth.standard,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                Breakpoints.of(width).isCompact
                    ? AppSpacing.md
                    : AppSpacing.xxl,
                horizontal,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: 'Expense Details',
                    leading: pageHeaderLeading(context),
                    actions: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: () =>
                            ref.invalidate(expenseProvider(expenseId)),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  expenseAsync.when(
                    loading: () => const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SkeletonBox(height: 112, radius: AppRadius.lg),
                        SizedBox(height: AppSpacing.xxl),
                        SkeletonBox(height: 200, radius: AppRadius.lg),
                      ],
                    ),
                    error: (error, _) => SurfaceCard(
                      child: ErrorState(
                        compact: true,
                        title: 'Unable to load this expense',
                        message: error is PostgrestException
                            ? error.message
                            : error.toString(),
                        retryLabel: 'Retry',
                        onRetry: () =>
                            ref.invalidate(expenseProvider(expenseId)),
                      ),
                    ),
                    data: (expense) => _DetailsBody(
                      expense: expense,
                      wide: width >= Breakpoints.expanded,
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

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.expense, required this.wide});

  final Expense expense;

  /// Desktop: expense information beside the record dates.
  final bool wide;

  String _dateTime(MaterialLocalizations localizations, DateTime value) {
    final local = value.toLocal();
    return '${localizations.formatMediumDate(local)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final expenseDate = localizations.formatMediumDate(expense.expenseDate);
    const gap = SizedBox(height: AppSpacing.xxl);

    final identity = IdentityPanel(
      visual: IconTile(icon: _categoryIcon(expense.category), size: 56),
      title: expense.category.label,
      subtitle: expenseDate,
    );

    final figures = MetricGrid(
      cards: [
        MetricCard(
          label: 'Amount',
          value: formatGhs(expense.amount),
          caption: expense.category.label,
          icon: Icons.account_balance_wallet_outlined,
          emphasized: true,
        ),
        MetricCard(
          label: 'Payment method',
          value: expense.paymentMethod.label,
          caption: 'How it was paid',
          icon: Icons.payments_outlined,
          tone: StatusTone.neutral,
        ),
      ],
    );

    final information = InfoSection(
      title: 'Expense Information',
      items: [
        InfoItem(label: 'Category', value: expense.category.label),
        InfoItem(label: 'Amount', value: formatGhs(expense.amount)),
        InfoItem(label: 'Payment method', value: expense.paymentMethod.label),
        InfoItem(label: 'Expense date', value: expenseDate),
        InfoItem(label: 'Reference', value: expense.reference, wide: true),
        InfoItem(label: 'Note', value: expense.note, wide: true),
      ],
    );

    final record = InfoSection(
      title: 'Record',
      items: [
        InfoItem(
          label: 'Recorded',
          value: _dateTime(localizations, expense.createdAt),
          wide: true,
        ),
        InfoItem(
          label: 'Last updated',
          value: _dateTime(localizations, expense.updatedAt),
          wide: true,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identity,
        const SizedBox(height: AppSpacing.lg),
        figures,
        gap,
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: information),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(flex: 2, child: record),
            ],
          )
        else ...[
          information,
          gap,
          record,
        ],
      ],
    );
  }

  static IconData _categoryIcon(ExpenseCategory category) {
    return switch (category) {
      ExpenseCategory.rent => Icons.home_work_outlined,
      ExpenseCategory.utilities => Icons.bolt_outlined,
      ExpenseCategory.transport => Icons.local_shipping_outlined,
      ExpenseCategory.salaries => Icons.badge_outlined,
      ExpenseCategory.supplies => Icons.inventory_2_outlined,
      ExpenseCategory.maintenance => Icons.build_outlined,
      ExpenseCategory.marketing => Icons.campaign_outlined,
      ExpenseCategory.communication => Icons.phone_in_talk_outlined,
      ExpenseCategory.other => Icons.receipt_outlined,
    };
  }
}
