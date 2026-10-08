import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// A shortcut to a common task.
///
/// The [primary] variant is the dominant filled action (one per group);
/// others are quiet outlined tiles. [stacked] puts the icon above the label
/// for narrow tiles laid out in a row.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.primary = false,
    this.stacked = false,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final bool primary;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: primary
          ? BorderSide.none
          : const BorderSide(color: AppColors.border),
    );

    return Semantics(
      button: true,
      child: Material(
        color: primary ? AppColors.primary : AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          hoverColor: primary ? null : AppColors.surfaceSubtle,
          child: stacked ? _stacked(context) : _horizontal(context),
        ),
      ),
    );
  }

  Widget _iconTile({double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary
            ? AppColors.textOnPrimary.withValues(alpha: 0.16)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        size: size * 0.52,
        color: primary ? AppColors.textOnPrimary : AppColors.primary,
      ),
    );
  }

  Widget _horizontal(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = this.description;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _iconTile(size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: primary
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: primary
                            ? AppColors.textOnPrimary.withValues(alpha: 0.78)
                            : AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: primary ? AppColors.textOnPrimary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stacked(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 88),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconTile(size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: primary
                    ? AppColors.textOnPrimary
                    : AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
