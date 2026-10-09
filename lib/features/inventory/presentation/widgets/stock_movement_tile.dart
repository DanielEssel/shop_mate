import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/stock_movement.dart';

/// A stock movement in a list: product, movement type, the stock before and
/// after, and the signed change.
class StockMovementTile extends StatelessWidget {
  const StockMovementTile({
    super.key,
    required this.movement,
    this.productName,
    this.onTap,
  });

  final StockMovement movement;
  final String? productName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = StockMovementType.of(movement.movementType);
    final name = productName?.trim();
    final note = movement.note?.trim();

    return ListRow(
      title: name == null || name.isEmpty ? 'Unknown product' : name,
      details: [
        type.label,
        '${movement.previousQuantity} to ${movement.newQuantity} units',
        formatDateTime(movement.createdAt),
        if (note != null && note.isNotEmpty) note,
      ],
      leading: IconTile(icon: type.icon, color: type.tone.foreground),
      trailing: StockChange(movement: movement),
      onTap: onTap,
    );
  }
}

/// How a movement type is shown: label, icon and semantic tone.
@immutable
class StockMovementType {
  const StockMovementType._(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static StockMovementType of(String type) {
    switch (type.toLowerCase()) {
      case 'purchase':
        return const StockMovementType._(
          'Purchase',
          Icons.shopping_cart_outlined,
          StatusTone.success,
        );
      case 'sale':
        return const StockMovementType._(
          'Sale',
          Icons.point_of_sale_rounded,
          StatusTone.info,
        );
      case 'return':
        return const StockMovementType._(
          'Stock Return',
          Icons.keyboard_return_rounded,
          StatusTone.info,
        );
      case 'opening':
        return const StockMovementType._(
          'Opening Stock',
          Icons.inventory_2_outlined,
          StatusTone.brand,
        );
      case 'adjustment':
      default:
        return const StockMovementType._(
          'Stock Adjustment',
          Icons.tune_rounded,
          StatusTone.warning,
        );
    }
  }

  /// The movement type as a badge (text and icon, never colour alone).
  Widget badge() => StatusBadge(label: label, tone: tone, icon: icon);
}

/// Whether a movement added stock. Uses the recorded before/after
/// quantities; when they are equal, falls back to the movement type.
bool isStockIncrease(StockMovement movement) {
  if (movement.newQuantity > movement.previousQuantity) {
    return true;
  }

  if (movement.newQuantity < movement.previousQuantity) {
    return false;
  }

  return movement.movementType == 'opening' ||
      movement.movementType == 'purchase' ||
      movement.movementType == 'return';
}

/// The signed quantity change with an up or down arrow.
class StockChange extends StatelessWidget {
  const StockChange({super.key, required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final increase = isStockIncrease(movement);
    final color = increase ? AppColors.success : AppColors.danger;

    return Semantics(
      label:
          '${increase ? 'Added' : 'Removed'} ${movement.quantity} '
          '${movement.quantity == 1 ? 'unit' : 'units'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            increase
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            increase ? '+${movement.quantity}' : '-${movement.quantity}',
            style: AppTypography.amount.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Stock before and after a movement, e.g. "40 → 28", with an arrow icon
/// (the arrow character is missing from the app font).
class StockLevels extends StatelessWidget {
  const StockLevels({super.key, required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.amount.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    );

    return Semantics(
      label: 'Stock ${movement.previousQuantity} to ${movement.newQuantity}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${movement.previousQuantity}', style: style),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
          Text('${movement.newQuantity}', style: style),
        ],
      ),
    );
  }
}
