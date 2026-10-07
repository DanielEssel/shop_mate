import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

enum AuthNoticeTone {
  error(Icons.error_outline_rounded, AppColors.error, AppColors.errorLight),
  warning(
    Icons.mark_email_unread_outlined,
    AppColors.warning,
    AppColors.warningLight,
  ),
  success(
    Icons.mark_email_read_outlined,
    AppColors.success,
    AppColors.successLight,
  );

  const AuthNoticeTone(this.icon, this.color, this.background);

  final IconData icon;
  final Color color;
  final Color background;
}

/// Inline message card for the auth forms, announced to screen readers when
/// it appears. [child] holds follow-up actions (e.g. resend, sign in).
class AuthNotice extends StatelessWidget {
  const AuthNotice({
    super.key,
    required this.tone,
    required this.message,
    this.title,
    this.child,
  });

  final AuthNoticeTone tone;
  final String? title;
  final String message;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = this.title;
    final child = this.child;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tone.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(tone.icon, size: 20, color: tone.color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (child != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    child,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
