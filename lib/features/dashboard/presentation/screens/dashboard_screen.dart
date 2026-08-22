import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_recent_sales.dart';
import '../widgets/dashboard_stat_card.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../widgets/dashboard_low_stock_banner.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            await ref.read(dashboardSummaryProvider.future);
          },
          child: dashboardAsync.when(
            loading: () => const _DashboardLoading(),
            error: (error, stackTrace) => _DashboardError(
              onRetry: () {
                ref.invalidate(dashboardSummaryProvider);
              },
            ),
            data: (summary) => _DashboardContent(
              summary: summary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.summary,
  });

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth >= 700
                ? AppSpacing.xxl
                : AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1440,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardHeader(),

const SizedBox(height: AppSpacing.xl),

if (!isWide) ...[
  DashboardLowStockBanner(
    summary: summary,
  ),

  const SizedBox(height: AppSpacing.xl),
],

_DashboardStats(
  summary: summary,
),

                  const SizedBox(height: AppSpacing.xxxl),

                  const DashboardQuickActions(),

                  const SizedBox(height: AppSpacing.xxxl),

                  

                  

                  const SizedBox(height: AppSpacing.xxxl),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DashboardRecentSales(
                            sales: summary.recentSales,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: _DashboardOverview(
                            summary: summary,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    DashboardRecentSales(
                      sales: summary.recentSales,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    _DashboardOverview(
                      summary: summary,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats({
    required this.summary,
  });

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 1100
            ? 4
            : 2;

        final spacing = width < 500
            ? AppSpacing.sm
            : AppSpacing.lg;

        final cardWidth =
            (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: DashboardStatCard(
                title: "Today's Sales",
                value: _formatCurrency(summary.todaySales),
                subtitle: 'Sales recorded today',
                icon: Icons.payments_rounded,
                iconBackgroundColor: AppColors.primaryLight,
                iconColor: AppColors.primary,
                onTap: () => context.go('/sales'),
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: DashboardStatCard(
                title: "Today's Profit",
                value: _formatCurrency(summary.todayProfit),
                subtitle: 'Estimated profit today',
                icon: Icons.trending_up_rounded,
                iconBackgroundColor: AppColors.successLight,
                iconColor: AppColors.success,
                valueColor: AppColors.success,
                onTap: () => context.go('/sales'),
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: DashboardStatCard(
                title: 'Transactions',
                value: summary.todayTransactions.toString(),
                subtitle: 'Sales transactions today',
                icon: Icons.receipt_long_rounded,
                iconBackgroundColor: AppColors.infoLight,
                iconColor: AppColors.info,
                onTap: () => context.go('/sales'),
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: DashboardStatCard(
                title: 'Products',
                value: summary.totalProducts.toString(),
                subtitle: _productSubtitle(summary),
                icon: Icons.inventory_2_rounded,
                iconBackgroundColor:
                    summary.lowStockProducts > 0
                        ? AppColors.warningLight
                        : AppColors.primaryLight,
                iconColor:
                    summary.lowStockProducts > 0
                        ? AppColors.warning
                        : AppColors.primary,
                valueColor: AppColors.textPrimary,
                onTap: () => context.go('/products'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _productSubtitle(DashboardSummary summary) {
    if (summary.outOfStockProducts > 0) {
      return '${summary.outOfStockProducts} out of stock';
    }

    if (summary.lowStockProducts > 0) {
      return '${summary.lowStockProducts} low stock';
    }

    return 'All products stocked';
  }

  String _formatCurrency(double amount) {
    return 'GH₵ ${amount.toStringAsFixed(2)}';
  }
}


class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.summary,
  });

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop Overview',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Current inventory status',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          _OverviewRow(
            icon: Icons.inventory_2_outlined,
            label: 'Total products',
            value: summary.totalProducts.toString(),
          ),

          const Divider(
            height: AppSpacing.xxl,
            color: AppColors.border,
          ),

          _OverviewRow(
            icon: Icons.warning_amber_rounded,
            label: 'Low stock',
            value: summary.lowStockProducts.toString(),
            valueColor: summary.lowStockProducts > 0
                ? AppColors.warning
                : AppColors.success,
          ),

          const Divider(
            height: AppSpacing.xxl,
            color: AppColors.border,
          ),

          _OverviewRow(
            icon: Icons.remove_shopping_cart_outlined,
            label: 'Out of stock',
            value: summary.outOfStockProducts.toString(),
            valueColor: summary.outOfStockProducts > 0
                ? AppColors.error
                : AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LoadingBox(
            width: 260,
            height: 34,
          ),
          SizedBox(height: AppSpacing.sm),
          _LoadingBox(
            width: 360,
            height: 18,
          ),
          SizedBox(height: AppSpacing.xxxl),
          _LoadingStats(),
        ],
      ),
    );
  }
}

class _LoadingStats extends StatelessWidget {
  const _LoadingStats();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 600
                ? 2
                : 1;

        const spacing = AppSpacing.lg;

        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth -
                    spacing * (columns - 1)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            4,
            (_) => SizedBox(
              width: width,
              child: const _LoadingBox(
                height: 180,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({
    this.width,
    required this.height,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Unable to load dashboard',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Something went wrong while loading your shop summary.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}