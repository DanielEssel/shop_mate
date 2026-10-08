import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';

/// Semantic tone for badges, metrics and indicators.
enum StatusTone {
  success(AppColors.success, AppColors.successLight),
  warning(AppColors.warning, AppColors.warningLight),
  danger(AppColors.danger, AppColors.dangerLight),
  info(AppColors.info, AppColors.infoLight),
  brand(AppColors.primary, AppColors.primarySoft),
  neutral(AppColors.textSecondary, AppColors.surfaceMuted);

  const StatusTone(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

/// A compact, scannable status label (IN STOCK, LOW STOCK, PAID…).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.showDot = true,
  });

  final String label;
  final StatusTone tone;

  /// Replaces the dot when given.
  final IconData? icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone.foreground),
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone.foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tone.foreground,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
