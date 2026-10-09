import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'app_shell_scope.dart';
import 'layout/breakpoints.dart';

/// Title block at the top of a main page: title, optional supporting line,
/// and page actions. On phones the actions wrap below the title.
///
/// [showMenuButton] puts the drawer button in front of the title on phone
/// widths (tab pages only). Pushed and secondary pages pass [leading]
/// instead, usually `pageHeaderLeading(context)`.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showMenuButton = false,
    this.leading,
    this.titleKey,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showMenuButton;

  /// Shown in front of the title (e.g. a back button). Takes precedence over
  /// the menu button.
  final Widget? leading;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final leading =
        this.leading ??
        (showMenuButton && AppMenuButton.isVisible(context)
            ? const AppMenuButton()
            : null);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          key: titleKey,
          style: textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Labelled buttons move below the title on phones; icon-only
        // actions (refresh, clear) are small enough to stay beside it.
        final iconOnly = actions.every((action) => action is IconButton);
        final stackActions =
            actions.isNotEmpty &&
            !iconOnly &&
            Breakpoints.of(constraints.maxWidth).isCompact;

        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: leading != null ? 4 : 0),
                child: titleBlock,
              ),
            ),
            if (!stackActions && actions.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ],
        );

        if (!stackActions) return heading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        );
      },
    );
  }
}

/// Heading for a section within a page, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shown instead of the text action when given.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing case final trailing?)
          trailing
        else if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              textStyle: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small uppercase label (navigation sections, metric labels).
class OverlineText extends StatelessWidget {
  const OverlineText(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.overline.copyWith(
        color: color ?? AppColors.textMuted,
      ),
    );
  }
}
