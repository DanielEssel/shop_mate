import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/supplier.dart';
import '../providers/supplier_providers.dart';
import '../widgets/supplier_card.dart';

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
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = Breakpoints.of(width).isCompact;
            final horizontal = Breakpoints.pagePadding(
              width,
              maxWidth: ContentWidth.standard,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isCompact ? AppSpacing.md : AppSpacing.xxl,
                horizontal,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: 'Supplier Details',
                    leading: pageHeaderLeading(context),
                    actions: [
                      if (!isCompact)
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () =>
                              ref.invalidate(supplierProvider(supplierId)),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      if (supplierAsync.hasValue)
                        PrimaryButton(
                          label: 'Edit supplier',
                          icon: Icons.edit_outlined,
                          onPressed: () => _edit(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  supplierAsync.when(
                    loading: () => const _DetailsSkeleton(),
                    error: (_, _) => SurfaceCard(
                      child: ErrorState(
                        compact: true,
                        title: 'Unable to load this supplier',
                        message: 'Check your connection and try again.',
                        retryLabel: 'Retry',
                        onRetry: () =>
                            ref.invalidate(supplierProvider(supplierId)),
                      ),
                    ),
                    data: (supplier) => _DetailsBody(
                      supplier: supplier,
                      wide: width >= Breakpoints.expanded,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.supplier, required this.wide});

  final Supplier supplier;

  /// Desktop: contact information beside the record dates.
  final bool wide;

  /// Full date (with year) and time, e.g. "Thursday, October 1, 2026, 9:30 AM".
  String _dateTime(MaterialLocalizations localizations, DateTime value) {
    final local = value.toLocal();
    return '${localizations.formatFullDate(local)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    final identity = IdentityPanel(
      visual: InitialAvatar(name: supplier.name, size: 64),
      title: supplier.name,
      subtitle: 'Supplier',
      badges: [SupplierListStatusBadge(isActive: supplier.isActive)],
      footer: supplier.isActive
          ? null
          : Text(
              'Inactive suppliers are kept for records. Edit the supplier to '
              'reactivate them.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
    );

    final information = InfoSection(
      title: 'Supplier Information',
      items: [
        InfoItem(label: 'Phone', value: supplier.phone),
        InfoItem(label: 'Email', value: supplier.email),
        InfoItem(label: 'Address', value: supplier.address, wide: true),
        InfoItem(label: 'Notes', value: supplier.notes, wide: true),
      ],
    );

    final record = InfoSection(
      title: 'Record',
      items: [
        InfoItem(
          label: 'Created',
          value: _dateTime(localizations, supplier.createdAt),
          wide: true,
        ),
        InfoItem(
          label: 'Last updated',
          value: _dateTime(localizations, supplier.updatedAt),
          wide: true,
        ),
      ],
    );

    const gap = SizedBox(height: AppSpacing.xxl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identity,
        gap,
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: information),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(flex: 2, child: record),
            ],
          )
        else ...[
          information,
          gap,
          record,
        ],
      ],
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 112, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.xxl),
        SkeletonBox(height: 180, radius: AppRadius.lg),
      ],
    );
  }
}
