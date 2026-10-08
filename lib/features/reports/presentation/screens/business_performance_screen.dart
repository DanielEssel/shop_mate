import 'package:flutter/material.dart';
import '../../../../core/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/business_performance.dart';
import '../../domain/entities/report_date_range.dart';
import '../providers/report_period_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/performance_metrics.dart';
import '../widgets/report_period_selector.dart';

/// Profit and loss for a selected period. Every figure comes from the
/// `get_business_performance` RPC; nothing is recalculated here.
class BusinessPerformanceScreen extends ConsumerWidget {
  const BusinessPerformanceScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final before = ref.read(reportPeriodProvider).range;
    ref.read(reportPeriodProvider.notifier).refreshRelativeRange();
    final range = ref.read(reportPeriodProvider).range;

    // A new day yields a new range, which loads on its own; otherwise reload.
    if (range == before) {
      ref.invalidate(businessPerformanceProvider(range));
    }

    try {
      await ref.read(businessPerformanceProvider(range).future);
    } catch (_) {
      // The error is shown inline by the screen's error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final performanceAsync = ref.watch(
      businessPerformanceProvider(period.range),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: secondaryPageLeading(context),
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Business Performance',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: performanceAsync.isLoading ? null : () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: performanceAsync.isRefreshing
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
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
                  AppSpacing.xxxl,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sales, cost of goods sold, expenses and profit '
                            'for the selected period.',
                            style: AppTypography.textTheme.bodyMedium!.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const ReportPeriodSelector(),
                          const SizedBox(height: AppSpacing.lg),
                          // Never show placeholder zeros: the first load of a
                          // range is a spinner, not an empty result.
                          performanceAsync.when(
                            loading: () => const _LoadingState(),
                            error: (error, _) => _ErrorState(
                              error: error,
                              onRetry: () => _refresh(ref),
                            ),
                            data: (performance) =>
                                _PerformanceBody(performance: performance),
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

class _PerformanceBody extends StatelessWidget {
  const _PerformanceBody({required this.performance});

  final BusinessPerformance performance;

  @override
  Widget build(BuildContext context) {
    if (performance.salesCount == 0 && performance.expenseCount == 0) {
      return _NoActivityState(range: performance.range);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NetProfitCard(performance: performance),
        const SizedBox(height: AppSpacing.md),
        PerformanceMetricsGrid(performance: performance),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Credit sales count when the sale is made. Stock purchases are '
          'not expenses; their cost is included in cost of goods sold when '
          'the goods are sold.',
          style: AppTypography.textTheme.bodySmall!.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.section),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NoActivityState extends StatelessWidget {
  const _NoActivityState({required this.range});

  final ReportDateRange range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.section,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 44,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No activity in this period',
            style: AppTypography.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No sales or expenses were recorded for '
            '${formatReportRange(context, range)}. '
            'Choose a longer period to see your results.',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final detail = error is PostgrestException
        ? (error as PostgrestException).message
        : 'Check your connection and try again.';

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
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
            'Unable to load business performance',
            textAlign: TextAlign.center,
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
