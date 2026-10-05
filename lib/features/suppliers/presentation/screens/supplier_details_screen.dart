import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/supplier.dart';
import '../providers/supplier_providers.dart';
import '../widgets/supplier_status_badge.dart';

/// Read-only view of one supplier, with an Edit action.
class SupplierDetailsScreen extends ConsumerWidget {
  const SupplierDetailsScreen({super.key, required this.supplierId});

  final String supplierId;

  void _edit(BuildContext context) {
    context.push('/suppliers/$supplierId/edit');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierProvider(supplierId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Supplier Details',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(supplierProvider(supplierId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (supplierAsync.hasValue)
            IconButton(
              tooltip: 'Edit supplier',
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: supplierAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _DetailsError(
            onRetry: () => ref.invalidate(supplierProvider(supplierId)),
          ),
          data: (supplier) =>
              _DetailsBody(supplier: supplier, onEdit: () => _edit(context)),
        ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.supplier, required this.onEdit});

  final Supplier supplier;
  final VoidCallback onEdit;

  /// Full date (with year) and time, e.g. "Thursday, October 1, 2026, 9:30 AM".
  String _dateTime(MaterialLocalizations localizations, DateTime value) {
    final local = value.toLocal();
    return '${localizations.formatFullDate(local)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        supplier.name,
                        style: AppTypography.textTheme.headlineSmall!.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SupplierStatusBadge(isActive: supplier.isActive),
                      if (!supplier.isActive) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Inactive suppliers are kept for records. Edit the '
                          'supplier to reactivate them.',
                          style: AppTypography.textTheme.bodySmall!.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      _DetailRow(label: 'Phone', value: supplier.phone),
                      _DetailRow(label: 'Email', value: supplier.email),
                      _DetailRow(label: 'Address', value: supplier.address),
                      _DetailRow(label: 'Notes', value: supplier.notes),
                      _DetailRow(
                        label: 'Created',
                        value: _dateTime(localizations, supplier.createdAt),
                      ),
                      _DetailRow(
                        label: 'Last updated',
                        value: _dateTime(localizations, supplier.updatedAt),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit supplier'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;

  /// Shown as "Not provided" when absent.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SelectableText(
              text ?? 'Not provided',
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: text == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontWeight: text == null ? FontWeight.w400 : FontWeight.w600,
                fontStyle: text == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load this supplier',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check your connection and try again.',
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
      ),
    );
  }
}
