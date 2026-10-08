import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_inventory_health.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_recent_sales.dart';

/// "How is my shop doing right now?" — today's figures, the main actions,
/// stock health and the latest sales, all from the dashboard summary.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardSummaryProvider);
    // Attendants get an operational dashboard: no profit, no stock
    // adjustment (the database omits their profit figure as well).
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            await ref.read(dashboardSummaryProvider.future);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontal = Breakpoints.pagePadding(
                width,
                maxWidth: ContentWidth.standard,
              );

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                    const DashboardHeader(),
                    const SizedBox(height: AppSpacing.xxl),
                    dashboardAsync.when(
                      loading: () => const _DashboardLoading(),
                      error: (error, stackTrace) => SurfaceCard(
                        child: ErrorState(
                          title: 'Unable to load dashboard',
                          message:
                              'Something went wrong while loading your shop summary.',
                          onRetry: () {
                            ref.invalidate(dashboardSummaryProvider);
                          },
                        ),
                      ),
                      data: (summary) =>
                          _DashboardContent(summary: summary, isOwner: isOwner),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary, required this.isOwner});

  final DashboardSummary summary;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.of(constraints.maxWidth);

        final metrics = _DashboardMetrics(
          summary: summary,
          showProfit: isOwner,
        );
        final actions = DashboardQuickActions(canAdjustStock: isOwner);
        final health = DashboardInventoryHealth(summary: summary);
        final recent = DashboardRecentSales(sales: summary.recentSales);

        if (size.isAtLeastExpanded) {
          // Desktop: figures across the top, then the working area (actions
          // and recent sales) beside the stock panel.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metrics,
              const SizedBox(height: AppSpacing.xxl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        actions,
                        const SizedBox(height: AppSpacing.xxl),
                        recent,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Stock'),
                        const SizedBox(height: AppSpacing.md),
                        health,
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        if (size.isAtLeastMedium) {
          // Tablet: actions beside stock health, recent sales below.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metrics,
              const SizedBox(height: AppSpacing.xxl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Stock'),
                        const SizedBox(height: AppSpacing.md),
                        health,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              recent,
            ],
          );
        }

        // Phone: figures, the main action, stock health, recent activity.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            metrics,
            const SizedBox(height: AppSpacing.xxl),
            actions,
            const SizedBox(height: AppSpacing.xxl),
            health,
            const SizedBox(height: AppSpacing.xxl),
            recent,
          ],
        );
      },
    );
  }
}

/// Today's key figures. Sales leads on the brand surface; the rest follow.
class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({required this.summary, required this.showProfit});

  final DashboardSummary summary;

  /// Owners only: an attendant's summary carries no profit figure, and a
  /// placeholder 0 would be misleading.
  final bool showProfit;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      MetricCard(
        label: "Today's Sales",
        value: formatGhs(summary.todaySales),
        caption: 'Sales recorded today',
        icon: Icons.payments_outlined,
        emphasized: true,
        onTap: () => context.go('/sales'),
      ),
      if (showProfit)
        MetricCard(
          label: "Today's Profit",
          value: formatGhs(summary.todayProfit),
          caption: 'Estimated profit today',
          icon: Icons.trending_up_rounded,
          tone: StatusTone.success,
          onTap: () => context.go('/sales'),
        ),
      MetricCard(
        label: 'Transactions',
        value: '${summary.todayTransactions}',
        caption: 'Sales transactions today',
        icon: Icons.receipt_long_outlined,
        tone: StatusTone.info,
        onTap: () => context.go('/sales'),
      ),
      MetricCard(
        label: 'Products',
        value: '${summary.totalProducts}',
        caption: _productCaption(summary),
        captionTone: summary.outOfStockProducts > 0
            ? StatusTone.danger
            : summary.lowStockProducts > 0
            ? StatusTone.warning
            : null,
        icon: Icons.inventory_2_outlined,
        tone: StatusTone.brand,
        onTap: () => context.go('/products'),
      ),
    ];

    return MetricGrid(cards: cards);
  }

  static String _productCaption(DashboardSummary summary) {
    if (summary.outOfStockProducts > 0) {
      return '${summary.outOfStockProducts} out of stock';
    }
    if (summary.lowStockProducts > 0) {
      return '${summary.lowStockProducts} low stock';
    }
    return 'All products stocked';
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading dashboard',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = Breakpoints.of(constraints.maxWidth).isAtLeastExpanded
              ? 4
              : 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: SkeletonBox(height: 112, radius: AppRadius.lg),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SkeletonBox(height: 64, radius: AppRadius.lg),
              const SizedBox(height: AppSpacing.xxl),
              const SkeletonList(rows: 4),
            ],
          );
        },
      ),
    );
  }
}
