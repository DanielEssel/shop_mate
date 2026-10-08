import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'headers.dart';
import 'surfaces.dart';

/// Who or what a details page is about: a visual (photo or initial), the
/// name as the dominant text, a supporting line and status badges.
class IdentityPanel extends StatelessWidget {
  const IdentityPanel({
    super.key,
    required this.visual,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.footer,
  });

  /// Photo, thumbnail or initial avatar, about 56–72 px.
  final Widget visual;
  final String title;
  final String? subtitle;
  final List<Widget> badges;

  /// Optional note under the identity (e.g. why a record is inactive).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    final footer = this.footer;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              visual,
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: badges,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            footer,
          ],
        ],
      ),
    );
  }
}

/// One fact in an [InfoSection]. A null or blank [value] shows
/// [placeholder] in a muted style.
class InfoItem {
  const InfoItem({
    required this.label,
    required this.value,
    this.placeholder = 'Not provided',
    this.wide = false,
  });

  final String label;
  final String? value;
  final String placeholder;

  /// Takes a full row even when the section shows two columns (long text
  /// such as notes or descriptions).
  final bool wide;
}

/// A titled, bordered group of label/value facts. Two columns from about
/// tablet width, one on phones; rows are separated by hairlines rather than
/// boxed individually.
class InfoSection extends StatelessWidget {
  const InfoSection({
    super.key,
    required this.items,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final List<InfoItem> items;

  @override
  Widget build(BuildContext context) {
    final title = this.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          SectionHeader(title: title, subtitle: subtitle, trailing: trailing),
          const SizedBox(height: AppSpacing.md),
        ],
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 520;
              final rows = <List<InfoItem>>[];

              for (final item in items) {
                final last = rows.isEmpty ? null : rows.last;
                if (twoColumns &&
                    !item.wide &&
                    last != null &&
                    last.length == 1 &&
                    !last.single.wide) {
                  last.add(item);
                } else {
                  rows.add([item]);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var j = 0; j < rows[i].length; j++) ...[
                            if (j > 0) const SizedBox(width: AppSpacing.xl),
                            Expanded(child: _InfoValue(item: rows[i][j])),
                          ],
                          // Keep a lone item in a two-column row at half
                          // width so columns line up.
                          if (twoColumns &&
                              rows[i].length == 1 &&
                              !rows[i].single.wide) ...[
                            const SizedBox(width: AppSpacing.xl),
                            const Spacer(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoValue extends StatelessWidget {
  const _InfoValue({required this.item});

  final InfoItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final value = item.value?.trim();
    final missing = value == null || value.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          missing ? item.placeholder : value,
          style: textTheme.bodyMedium?.copyWith(
            color: missing ? AppColors.textMuted : AppColors.textPrimary,
            fontWeight: missing ? FontWeight.w400 : FontWeight.w500,
            fontStyle: missing ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

/// A titled, bordered group of form fields.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(padding: const EdgeInsets.all(AppSpacing.xl), child: child),
      ],
    );
  }
}

/// Puts form fields side by side when there is room (about tablet width)
/// and stacks them on phones.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                children[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.lg),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// The bar pinned under an edit form: Cancel and the one Save action.
/// Lives in the body so it rises with the keyboard; on wide windows the
/// buttons line up with a form no wider than [maxContentWidth].
class FormActionBar extends StatelessWidget {
  const FormActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon = Icons.check_rounded,
    this.isBusy = false,
    this.busyLabel,
    this.secondaryLabel = 'Cancel',
    this.onSecondary,
    this.maxContentWidth = 880,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData primaryIcon;
  final bool isBusy;

  /// Shown on the primary button while [isBusy].
  final String? busyLabel;

  final String secondaryLabel;

  /// Hidden when null.
  final VoidCallback? onSecondary;
  final double maxContentWidth;

  /// Space to leave under floating messages so they sit above this bar.
  static const double messageClearance = 96;

  @override
  Widget build(BuildContext context) {
    final onSecondary = this.onSecondary;

    final primary = FilledButton.icon(
      onPressed: isBusy ? null : onPrimary,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        disabledBackgroundColor: isBusy ? AppColors.primary : null,
        disabledForegroundColor: isBusy ? AppColors.textOnPrimary : null,
      ),
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textOnPrimary,
              ),
            )
          : Icon(primaryIcon, size: 18),
      label: Text(
        isBusy ? busyLabel ?? primaryLabel : primaryLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final secondary = onSecondary == null
        ? null
        : OutlinedButton(
            onPressed: isBusy ? null : onSecondary,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: Text(secondaryLabel),
          );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 480;

                  if (compact) {
                    return Row(
                      children: [
                        if (secondary != null) ...[
                          Expanded(child: secondary),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        Expanded(flex: 2, child: primary),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (secondary != null) ...[
                        secondary,
                        const SizedBox(width: AppSpacing.md),
                      ],
                      primary,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A floating message that clears a pinned bar of [clearance] height.
void showFloatingMessage(
  BuildContext context,
  String message, {
  double clearance = 0,
  Color? backgroundColor,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + clearance,
        ),
      ),
    );
}
