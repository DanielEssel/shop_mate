import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'status_badge.dart';

/// A key figure: label, the value as the dominant element, and one line of
/// supporting context.
///
/// [emphasized] renders the deep-green brand surface; use it for at most one
/// metric per screen (the one the screen is about).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.tone = StatusTone.neutral,
    this.captionTone,
    this.emphasized = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  /// Colours the icon.
  final StatusTone tone;

  /// Colours the caption (e.g. warning when something needs attention).
  final StatusTone? captionTone;

  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final background = emphasized ? AppColors.primaryDeep : AppColors.surface;
    final labelColor = emphasized
        ? AppColors.textOnPrimary.withValues(alpha: 0.72)
        : AppColors.textSecondary;
    final valueColor = emphasized
        ? AppColors.textOnPrimary
        : AppColors.textPrimary;
    final iconColor = emphasized ? AppColors.primaryBright : tone.foreground;
    final captionColor = emphasized
        ? AppColors.textOnPrimary.withValues(alpha: 0.64)
        : captionTone?.foreground ?? AppColors.textMuted;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: emphasized
          ? BorderSide.none
          : const BorderSide(color: AppColors.border),
    );

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(color: labelColor),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.metricLarge.copyWith(color: valueColor),
            ),
          ),
          if (caption case final caption?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: captionColor,
                fontWeight: captionTone != null && !emphasized
                    ? FontWeight.w500
                    : null,
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      child: Material(
        color: background,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, customBorder: shape, child: content),
      ),
    );
  }
}
