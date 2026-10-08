import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../domain/entities/supplier.dart';

/// A supplier in a list: initial, name and contact details, and an
/// Active/Inactive badge.
class SupplierCard extends StatelessWidget {
  const SupplierCard({super.key, required this.supplier, required this.onTap});

  final Supplier supplier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // How to reach them, then where they are; email shows when there is
    // no phone.
    final details = [?(supplier.phone ?? supplier.email), ?supplier.address];

    return Semantics(
      button: true,
      label:
          '${supplier.name}, ${supplier.isActive ? 'active' : 'inactive'} '
          'supplier. Open details.',
      excludeSemantics: true,
      child: ListRow(
        title: supplier.name,
        details: details.isEmpty ? const ['No contact details'] : details,
        leading: InitialAvatar(name: supplier.name),
        trailing: SupplierListStatusBadge(isActive: supplier.isActive),
        showChevron: true,
        onTap: onTap,
      ),
    );
  }
}

/// Active or Inactive as text plus icon, so status never relies on colour.
class SupplierListStatusBadge extends StatelessWidget {
  const SupplierListStatusBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return isActive
        ? const StatusBadge(
            label: 'Active',
            tone: StatusTone.success,
            icon: Icons.check_circle_outline_rounded,
          )
        : const StatusBadge(
            label: 'Inactive',
            tone: StatusTone.neutral,
            icon: Icons.block_rounded,
          );
  }
}
