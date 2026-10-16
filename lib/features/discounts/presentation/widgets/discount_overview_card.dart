import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/discount_scope.dart';
import '../../domain/entities/discount_settings.dart';
import 'discount_dates.dart';

/// What is saved right now (never the unsaved form).
class DiscountOverviewCard extends StatelessWidget {
  const DiscountOverviewCard({
    super.key,
    required this.settings,
    required this.now,
  });

  /// Null when the shop has no discount configuration.
  final DiscountSettings? settings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final settings = this.settings;
    if (settings == null) {
      return const SurfaceCard(
        child: EmptyState(
          compact: true,
          icon: Icons.sell_outlined,
          title: 'No discount set up',
          message:
              'Sales use normal prices. Choose a percentage and the products '
              'it applies to below.',
        ),
      );
    }

    final (statusLabel, statusTone) = settings.isActiveAt(now)
        ? ('Active', StatusTone.success)
        : settings.isEnabled
        ? ('Ended', StatusTone.warning)
        : ('Off', StatusTone.neutral);
    final endsAt = settings.endsAt;
    final selectedCount = settings.selectedProductIds.length;
    final scopeLabel = switch (settings.scope) {
      DiscountScope.allProducts => 'All products',
      DiscountScope.selectedProducts =>
        '$selectedCount selected ${selectedCount == 1 ? 'product' : 'products'}',
    };

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saved discount',
                  style: AppTypography.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusBadge(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              _Fact(label: 'Discount', value: settings.percentage.label),
              _Fact(label: 'Applies to', value: scopeLabel),
              _Fact(
                label: 'Ends',
                value: endsAt == null
                    ? 'No end date'
                    : formatDiscountEndDay(context, endsAt),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _explanation(settings, statusLabel),
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String _explanation(DiscountSettings settings, String status) {
    if (status == 'Off') return 'Switched off: sales use normal prices.';
    if (status == 'Ended') {
      return 'The end date has passed: sales use normal prices.';
    }
    return switch (settings.scope) {
      DiscountScope.allProducts =>
        '${settings.percentage.label} off every product, except any it would '
            'take below cost; those sell at their normal price.',
      DiscountScope.selectedProducts =>
        '${settings.percentage.label} off the selected products only. Other '
            'products sell at their normal price.',
    };
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.textTheme.labelSmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
