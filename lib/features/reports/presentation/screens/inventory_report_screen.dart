import 'package:flutter/material.dart';
import '../../../../core/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
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
      appBar: AppBar(
        leading: secondaryPageLeading(context),
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Inventory Report',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: reportAsync.isLoading ? null : () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: reportAsync.isRefreshing
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
                            'Current stock position and inventory value',
                            style: AppTypography.textTheme.bodyMedium!.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // Never show placeholder zeros: the first load is a
                          // spinner, not an empty result.
                          reportAsync.when(
                            loading: () => const _LoadingState(),
                            error: (error, _) => _ErrorState(
                              error: error,
                              onRetry: () => _refresh(ref),
                            ),
                            data: (report) => _ReportBody(report: report),
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

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    if (report.totalProducts == 0 &&
        report.unitsPurchased == 0 &&
        report.unitsSold == 0) {
      return const _NoInventoryState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InventoryValuationCards(report: report),
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeading(title: 'Stock position'),
        const SizedBox(height: AppSpacing.md),
        InventoryStockGrid(report: report),
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeading(title: 'Stock activity'),
        const SizedBox(height: AppSpacing.md),
        InventoryActivityGrid(report: report),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Values use current cost and selling prices for active products. '
          'Units purchased and sold cover all completed purchases and all '
          'sales, including credit sales.',
          style: AppTypography.textTheme.bodySmall!.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
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

class _NoInventoryState extends StatelessWidget {
  const _NoInventoryState();

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
            Icons.inventory_2_outlined,
            size: 44,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No inventory yet',
            style: AppTypography.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add products and record purchases to see your stock position '
            'and inventory value.',
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
            'Unable to load inventory report',
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
