import 'package:flutter/material.dart';
import '../../../../core/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/inventory_report.dart';
import '../providers/reports_provider.dart';
import '../widgets/inventory_metrics.dart';

/// Current stock position and value. Every figure comes from the
/// `get_inventory_report` RPC; nothing is recalculated here.
class InventoryReportScreen extends ConsumerWidget {
  const InventoryReportScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(inventoryReportProvider);

    try {
      await ref.read(inventoryReportProvider.future);
    } catch (_) {
      // The error is shown inline by the screen's error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(inventoryReportProvider);

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
                    title: 'Inventory Report',
                    subtitle: 'Current stock position and inventory value',
                    leading: pageHeaderLeading(context),
                    actions: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: reportAsync.isLoading
                            ? null
                            : () => _refresh(ref),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 2,
                    child: reportAsync.isRefreshing
                        ? const LinearProgressIndicator(minHeight: 2)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Never show placeholder zeros: the first load is a
                  // placeholder, not an empty result.
                  reportAsync.when(
                    loading: () => const _LoadingState(),
                    error: (error, _) => SurfaceCard(
                      child: ErrorState(
                        compact: true,
                        title: 'Unable to load inventory report',
                        message: error is PostgrestException
                            ? error.message
                            : 'Check your connection and try again.',
                        retryLabel: 'Retry',
                        onRetry: () => _refresh(ref),
                      ),
                    ),
                    data: (report) => _ReportBody(report: report),
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

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    if (report.totalProducts == 0 &&
        report.unitsPurchased == 0 &&
        report.unitsSold == 0) {
      return const SurfaceCard(
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No inventory yet',
          message:
              'Add products and record purchases to see your stock position '
              'and inventory value.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Inventory value',
          subtitle: 'What the stock on hand is worth',
        ),
        const SizedBox(height: AppSpacing.md),
        InventoryValuationCards(report: report),
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(
          title: 'Stock position',
          subtitle: 'Products and units on hand',
        ),
        const SizedBox(height: AppSpacing.md),
        InventoryStockGrid(report: report),
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(
          title: 'Stock activity',
          subtitle: 'Units moved in and out over time',
        ),
        const SizedBox(height: AppSpacing.md),
        InventoryActivityGrid(report: report),
        const SizedBox(height: AppSpacing.xl),
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
                  'Values use current cost and selling prices for active '
                  'products. Units purchased and sold cover all completed '
                  'purchases and all sales, including credit sales.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      label: 'Loading inventory report',
      child: const ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: 120, radius: AppRadius.lg),
            SizedBox(height: AppSpacing.xxl),
            SkeletonBox(height: 220, radius: AppRadius.lg),
          ],
        ),
      ),
    );
  }
}
