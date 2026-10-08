import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../../shop/presentation/widgets/business_profile_section.dart';

/// App settings: the Business Profile (shop information and logo, through
/// the shared branding state) and, for owners, product setup.
///
/// Desktop puts the profile beside the other groups; narrower windows stack
/// them in one readable column.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const double _profileMaxWidth = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(
      shopAccessProvider.select((access) => access.value?.isOwner ?? false),
    );

    // Kept to a readable width rather than stretched across the window.
    final profile = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _profileMaxWidth),
      child: const _SettingsSection(
        title: 'Business Profile',
        subtitle: 'Your shop information and branding',
        child: BusinessProfileSection(),
      ),
    );

    // Owner-only: staff do not see category management, and the database
    // also limits category changes to the owner.
    final productGroup = isOwner
        ? _SettingsSection(
            title: 'Products',
            subtitle: 'How your catalogue is organised',
            child: _SettingsGroup(
              rows: [
                _SettingsRow(
                  icon: Icons.category_outlined,
                  title: 'Product categories',
                  subtitle:
                      'Create, rename and archive your product '
                      'categories.',
                  onTap: () => context.push('/settings/categories'),
                ),
              ],
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = Breakpoints.of(constraints.maxWidth).isCompact;
            final twoColumns =
                productGroup != null &&
                constraints.maxWidth >= Breakpoints.expanded;
            final horizontal = Breakpoints.pagePadding(
              constraints.maxWidth,
              maxWidth: twoColumns ? ContentWidth.standard : _profileMaxWidth,
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
                    title: 'Settings',
                    subtitle: 'Shop profile, branding and product setup',
                    leading: pageHeaderLeading(context),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (twoColumns)
                    LayoutBuilder(
                      builder: (context, columns) {
                        // The profile takes up to 60% (never more than its
                        // readable width); the groups fill the rest.
                        final profileWidth =
                            ((columns.maxWidth - AppSpacing.xxl) * 0.6).clamp(
                              0.0,
                              _profileMaxWidth,
                            );

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: profileWidth, child: profile),
                            const SizedBox(width: AppSpacing.xxl),
                            Expanded(child: productGroup),
                          ],
                        );
                      },
                    )
                  else ...[
                    profile,
                    if (productGroup != null) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      productGroup,
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

/// Rows in one bordered section, divided under the text.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const RowDivider(indent: 64),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Icon, title, one-line description and a chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: title,
      details: [subtitle],
      leading: IconTile(icon: icon),
      showChevron: true,
      onTap: onTap,
    );
  }
}
