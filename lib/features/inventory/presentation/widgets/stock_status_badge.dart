import 'package:flutter/material.dart';

import '../../../products/domain/entities/product.dart';

class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({
    super.key,
    required this.product,
  });

  final Product product;

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;

    if (product.isOutOfStock) {
      label = 'Out of stock';
      icon = Icons.remove_circle_outline_rounded;
    } else if (product.isLowStock) {
      label = 'Low stock';
      icon = Icons.warning_amber_rounded;
    } else {
      label = 'In stock';
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor(product),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: _foregroundColor(product),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: _foregroundColor(product),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _foregroundColor(Product product) {
    if (product.isOutOfStock) {
      return Colors.red.shade700;
    }

    if (product.isLowStock) {
      return Colors.orange.shade800;
    }

    return const Color(0xFF087F5B);
  }

  Color _backgroundColor(Product product) {
    if (product.isOutOfStock) {
      return Colors.red.shade50;
    }

    if (product.isLowStock) {
      return Colors.orange.shade50;
    }

    return const Color(0xFFE8F5F1);
  }
}
