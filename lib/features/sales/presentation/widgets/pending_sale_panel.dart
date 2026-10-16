import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/pending_sale_request.dart';
import '../../domain/entities/sale_outcome.dart';
import '../providers/pending_sale_controller.dart';

/// Shown on New Sale while a submitted sale's outcome is unconfirmed (or a
/// saved sale cannot be read). New sales wait until it is resolved.
class PendingSalePanel extends StatelessWidget {
  const PendingSalePanel({
    super.key,
    required this.state,
    required this.onLookUp,
    required this.onRetry,
    required this.onAbandon,
    required this.onReload,
    required this.onOpenSales,
  });

  final PendingSaleState state;
  final VoidCallback onLookUp;
  final VoidCallback onRetry;
  final VoidCallback onAbandon;
  final VoidCallback onReload;
  final VoidCallback onOpenSales;

  static const _methodLabels = {
    'cash': 'cash',
    'mobile_money': 'mobile money',
    'card': 'card',
    'bank_transfer': 'bank transfer',
    'credit': 'credit',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pending = state.pending;
    final busy = state.busy;

    final (String title, String body) = switch (state.phase) {
      PendingSalePhase.unreadable => (
        'A saved sale could not be read',
        state.unreadableValue == null
            ? 'ShopMate saved a sale on this device whose result was not '
                  'confirmed, but cannot read it right now. Try again, and '
                  'check Sales.'
            : 'ShopMate saved a sale on this device whose result was not '
                  'confirmed, but cannot read it now. Check Sales to see '
                  'whether it was recorded. Setting it aside keeps it on '
                  'this device.',
      ),
      _ when pending == null => ('', ''),
      _ when state.lookedUpNotFound => (
        'No recorded sale found yet',
        '${describe(context, pending)} No recorded sale was found for it '
            'yet, but it may still be recorded. If the customer has already '
            'paid and is waiting, retry this same sale. If they did not pay '
            'or have left, set it aside: ShopMate keeps checking it.',
      ),
      _ when state.lookupFailed => (
        'Sale not confirmed',
        '${describe(context, pending)} ShopMate could not check it. Try '
            'again when connected. If the customer did not pay or has left, '
            'you can set it aside: ShopMate keeps checking it.',
      ),
      _ => (
        'Sale not confirmed',
        '${describe(context, pending)} It may or may not have been '
            'recorded. Do not charge the customer again.',
      ),
    };

    return Container(
      key: const ValueKey('pending-sale-panel'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Checking the sale',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (state.phase == PendingSalePhase.pending)
                FilledButton(
                  onPressed: busy ? null : onLookUp,
                  child: const Text('Check if it was recorded'),
                ),
              if (state.phase == PendingSalePhase.pending &&
                  state.lookedUpNotFound)
                OutlinedButton(
                  onPressed: busy ? null : onRetry,
                  child: const Text('Retry this sale'),
                ),
              if (state.phase == PendingSalePhase.unreadable &&
                  state.unreadableValue == null)
                FilledButton(
                  onPressed: busy ? null : onReload,
                  child: const Text('Try again'),
                ),
              OutlinedButton(
                onPressed: busy ? null : onOpenSales,
                child: const Text('Check Sales'),
              ),
              if (state.canAbandon)
                TextButton(
                  onPressed: busy ? null : onAbandon,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('Set aside'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "A cash sale of 2 items (about GHS 30.00) was sent at 9:30 AM."
  static String describe(BuildContext context, PendingSaleRequest pending) {
    final draft = pending.draft;
    final local = pending.createdAt.toLocal();
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final method = _methodLabels[draft.paymentMethod] ?? draft.paymentMethod;
    final items = draft.itemCount == 1 ? '1 item' : '${draft.itemCount} items';
    return 'A $method sale of $items (about '
        '${formatGhs(draft.estimatedTotal)}) was sent at $time.';
  }
}

/// A sale the cashier set aside was recorded after all (its original
/// request reached the database later). Shown until acknowledged.
class AbandonedSaleRecordedNotice extends StatelessWidget {
  const AbandonedSaleRecordedNotice({
    super.key,
    required this.item,
    required this.onOpenSale,
    required this.onAcknowledge,
  });

  final AbandonedSaleRecorded item;
  final VoidCallback onOpenSale;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sale = item.recorded.sale;
    final recordedAs = sale == null
        ? 'It is in Sales.'
        : 'It was recorded as ${sale.saleNumber} '
              '(${formatGhs(sale.totalAmount)}) and is in Sales.';

    return Container(
      key: ValueKey('abandoned-sale-${item.abandoned.request.idempotencyKey}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A sale you set aside was recorded',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${PendingSalePanel.describe(context, item.abandoned.request)} '
            '$recordedAs Its stock was taken. Check whether the customer '
            'paid and took the goods, and correct it if not.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: onOpenSale,
                child: const Text('Open sale'),
              ),
              TextButton(onPressed: onAcknowledge, child: const Text('Got it')),
            ],
          ),
        ],
      ),
    );
  }
}
