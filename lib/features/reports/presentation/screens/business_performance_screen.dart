import 'package:flutter/material.dart';
import '../../../../core/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/business_performance.dart';
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
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontal = Breakpoints.pagePadding(
              width,
              maxWidth: ContentWidth.standard,
            );

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  Breakpoints.of(width).isCompact
                      ? AppSpacing.md
                      : AppSpacing.xxl,
                  horizontal,
                  AppSpacing.xxxl,
                ),
                children: [
                  PageHeader(
                    title: 'Business Performance',
                    subtitle:
                        'Sales, cost of goods sold, expenses and profit for '
                        'the selected period.',
                    leading: pageHeaderLeading(context),
                    actions: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: performanceAsync.isLoading
                            ? null
                            : () => _refresh(ref),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const ReportPeriodSelector(),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 2,
                    child: performanceAsync.isRefreshing
                        ? const LinearProgressIndicator(minHeight: 2)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Never show placeholder zeros: the first load of a range
                  // is a placeholder, not an empty result.
                  performanceAsync.when(
                    loading: () => const _LoadingState(),
                    error: (error, _) => SurfaceCard(
                      child: ErrorState(
                        compact: true,
                        title: 'Unable to load business performance',
                        message: error is PostgrestException
                            ? error.message
                            : 'Check your connection and try again.',
                        retryLabel: 'Retry',
                        onRetry: () => _refresh(ref),
                      ),
                    ),
                    data: (performance) => _PerformanceBody(
                      performance: performance,
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

class _PerformanceBody extends StatelessWidget {
  const _PerformanceBody({required this.performance, required this.wide});

  final BusinessPerformance performance;

  /// Desktop: the statement beside the notes on how figures are counted.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (performance.salesCount == 0 && performance.expenseCount == 0) {
      return SurfaceCard(
        child: EmptyState(
          icon: Icons.insights_outlined,
          title: 'No activity in this period',
          message:
              'No sales or expenses were recorded for '
              '${formatReportRange(context, performance.range)}. '
              'Choose a longer period to see your results.',
        ),
      );
    }

    const notes = _ReportNotes(
      text:
          'Credit sales count when the sale is made. Stock purchases are '
          'not expenses; their cost is included in cost of goods sold when '
          'the goods are sold.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PerformanceKeyFigures(performance: performance),
        const SizedBox(height: AppSpacing.xxl),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ProfitAndLossStatement(performance: performance),
              ),
              const SizedBox(width: AppSpacing.xxl),
              const Expanded(flex: 2, child: notes),
            ],
          )
        else ...[
          ProfitAndLossStatement(performance: performance),
          const SizedBox(height: AppSpacing.lg),
          notes,
        ],
      ],
    );
  }
}

/// How the figures are counted, kept with the figures.
class _ReportNotes extends StatelessWidget {
  const _ReportNotes({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'About these figures'),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          color: AppColors.surfaceSubtle,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
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
    return Semantics(
      container: true,
      label: 'Loading business performance',
      child: const ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 120, radius: AppRadius.lg),
            SizedBox(height: AppSpacing.xxl),
            SkeletonBox(height: 280, radius: AppRadius.lg),
          ],
        ),
      ),
    );
  }
}
