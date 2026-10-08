import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'status_badge.dart';

/// A tappable list row: leading visual, title and supporting line, and a
/// trailing value column. Rows sit inside a section separated by dividers
/// rather than each being its own card.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.details = const [],
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.showChevron = false,
  });

  final String title;

  /// Supporting facts under the title (category, time, payment method…),
  /// each its own text, separated by dots.
  final List<String> details;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final leading = this.leading;
    final trailing = this.trailing;
    final details = [
      for (final detail in this.details)
        if (detail.trim().isNotEmpty) detail,
    ];

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    DetailLine(details: details),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              trailing,
            ],
            if (showChevron) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return InkWell(onTap: onTap, child: content);
  }
}

/// Muted facts separated by dots, each its own text. The last ones give way
/// first: each one shown needs about [_minDetailWidth], and on narrow rows
/// the rest are left out rather than squeezed.
class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.details});

  final List<String> details;

  static const double _minDetailWidth = 72;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = (constraints.maxWidth / _minDetailWidth).floor();
        final shown = details.take(fit.clamp(1, details.length)).toList();

        return Row(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) ExcludeSemantics(child: Text('  ·  ', style: style)),
              Flexible(
                child: Text(
                  shown[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: style,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Right-aligned primary value with an optional secondary line.
class RowValue extends StatelessWidget {
  const RowValue({
    super.key,
    required this.value,
    this.caption,
    this.badge,
    this.valueColor = AppColors.textPrimary,
  });

  final String value;
  final String? caption;
  final Widget? badge;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    final badge = this.badge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          style: AppTypography.amount.copyWith(color: valueColor),
        ),
        if (badge != null) ...[
          const SizedBox(height: AppSpacing.xs),
          badge,
        ] else if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// A product in a list: identity on the left, price and stock status on the
/// right.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.name,
    required this.price,
    required this.stockLabel,
    required this.statusLabel,
    required this.statusTone,
    this.details = const [],
    this.leading,
    this.onTap,
  });

  final String name;

  /// Category, SKU or other identifying details.
  final List<String> details;

  /// Formatted selling price.
  final String price;

  /// e.g. "24 in stock".
  final String stockLabel;

  final String statusLabel;
  final StatusTone statusTone;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: name,
      details: [...details, stockLabel],
      leading: leading ?? InitialAvatar(name: name),
      onTap: onTap,
      trailing: RowValue(
        value: price,
        badge: StatusBadge(label: statusLabel, tone: statusTone),
      ),
    );
  }
}

/// A money movement (sale, purchase, expense, payment) in a list.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.reference,
    required this.amount,
    required this.icon,
    this.details = const [],
    this.timestamp,
    this.statusLabel,
    this.statusTone = StatusTone.neutral,
    this.amountColor = AppColors.textPrimary,
    this.onTap,
  });

  /// Sale number, purchase number or expense title.
  final String reference;

  /// Formatted amount.
  final String amount;
  final IconData icon;

  /// Customer, supplier, item count, payment method…
  final List<String> details;

  /// Formatted date/time.
  final String? timestamp;

  final String? statusLabel;
  final StatusTone statusTone;
  final Color amountColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = this.statusLabel;

    return ListRow(
      title: reference,
      details: [...details, ?timestamp],
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
      trailing: RowValue(
        value: amount,
        valueColor: amountColor,
        badge: statusLabel == null
            ? null
            : StatusBadge(label: statusLabel, tone: statusTone),
      ),
    );
  }
}

/// A rounded square with the first letter of [name].
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.4,
            height: 1,
          ),
        ),
      ),
    );
  }
}
