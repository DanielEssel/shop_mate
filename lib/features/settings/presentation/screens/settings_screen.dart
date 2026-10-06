import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../../shop/presentation/widgets/business_profile_section.dart';

/// App settings. Currently holds the Business Profile (shop information and
/// logo); further sections can be added below it.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Settings',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? AppSpacing.xl : AppSpacing.md,
                isDesktop ? AppSpacing.lg : AppSpacing.sm,
                isDesktop ? AppSpacing.xl : AppSpacing.md,
                AppSpacing.xxxl,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Business Profile',
                          style: AppTypography.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Manage your shop information and branding.',
                          style: AppTypography.textTheme.bodyMedium!.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const BusinessProfileSection(),
                        const _ProductCategoriesEntry(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Owner-only link to category management. Staff do not see it; the
/// database also limits category changes to the owner.
class _ProductCategoriesEntry extends ConsumerWidget {
  const _ProductCategoriesEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(
      shopAccessProvider.select((access) => access.value?.isOwner ?? false),
    );
    if (!isOwner) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Products',
            style: AppTypography.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Product categories'),
              subtitle: const Text(
                'Create, rename and archive your product categories.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/categories'),
            ),
          ),
        ],
      ),
    );
  }
}
