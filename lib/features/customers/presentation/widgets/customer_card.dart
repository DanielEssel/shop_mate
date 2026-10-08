import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/customer.dart';

/// A customer in a list: initial, name and how to reach them, with the
/// row's actions menu.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Customer customer;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final contact = customerContactLabel(customer);
    final address = _nonEmpty(customer.address);

    return ListRow(
      title: customer.name,
      details: [contact ?? 'No contact information', ?address],
      leading: InitialAvatar(name: customer.name),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!customer.isActive)
            const StatusBadge(label: 'Inactive', tone: StatusTone.neutral),
          CustomerActionsMenu(onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

/// Edit, and for owners Deactivate. [onDelete] is null for attendants, so
/// the option is not offered.
class CustomerActionsMenu extends StatelessWidget {
  const CustomerActionsMenu({super.key, this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Customer actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit customer'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        // Only offered when a delete action is provided (owners).
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Deactivate customer'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

/// Phone if there is one, otherwise email; null when neither is set.
String? customerContactLabel(Customer customer) {
  return _nonEmpty(customer.phone) ?? _nonEmpty(customer.email);
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
