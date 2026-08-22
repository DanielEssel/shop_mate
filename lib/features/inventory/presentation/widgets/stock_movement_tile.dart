import 'package:flutter/material.dart';

import '../../domain/entities/stock_movement.dart';

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
    final config = _movementConfig(movement.movementType);
    final isIncrease = _isIncrease(movement);

    final quantityText = isIncrease
        ? '+${movement.quantity}'
        : '-${movement.quantity}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE9ECEF),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MovementIcon(
                icon: config.icon,
                backgroundColor: config.backgroundColor,
                foregroundColor: config.foregroundColor,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            config.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          quantityText,
                          style: TextStyle(
                            color: config.foregroundColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (productName != null &&
                        productName!.trim().isNotEmpty)
                      Text(
                        productName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${movement.previousQuantity} → ${movement.newQuantity} units',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(movement.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (movement.note != null &&
                        movement.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          movement.note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isIncrease(StockMovement movement) {
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

  _MovementConfig _movementConfig(String type) {
    switch (type.toLowerCase()) {
      case 'purchase':
        return const _MovementConfig(
          label: 'Purchase',
          icon: Icons.shopping_cart_outlined,
          backgroundColor: Color(0xFFE8F5F1),
          foregroundColor: Color(0xFF087F5B),
        );

      case 'sale':
        return const _MovementConfig(
          label: 'Sale',
          icon: Icons.point_of_sale_rounded,
          backgroundColor: Color(0xFFFFF1F2),
          foregroundColor: Color(0xFFC92A2A),
        );

      case 'return':
        return const _MovementConfig(
          label: 'Stock Return',
          icon: Icons.keyboard_return_rounded,
          backgroundColor: Color(0xFFE7F5FF),
          foregroundColor: Color(0xFF1971C2),
        );

      case 'opening':
        return const _MovementConfig(
          label: 'Opening Stock',
          icon: Icons.inventory_2_outlined,
          backgroundColor: Color(0xFFF3F0FF),
          foregroundColor: Color(0xFF6741D9),
        );

      case 'adjustment':
      default:
        return const _MovementConfig(
          label: 'Stock Adjustment',
          icon: Icons.tune_rounded,
          backgroundColor: Color(0xFFFFF4E6),
          foregroundColor: Color(0xFFE67700),
        );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute =
        local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day}/${local.month}/${local.year} '
        '$hour:$minute $period';
  }
}

class _MovementIcon extends StatelessWidget {
  const _MovementIcon({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: foregroundColor,
        size: 21,
      ),
    );
  }
}

class _MovementConfig {
  const _MovementConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}