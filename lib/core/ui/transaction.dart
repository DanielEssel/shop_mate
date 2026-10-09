import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'inputs.dart';

/// Minus / count / plus in one bordered control, with 40px touch targets.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    this.itemName,
  });

  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  /// Used in the button tooltips, e.g. "Decrease Rice".
  final String? itemName;

  @override
  Widget build(BuildContext context) {
    final name = itemName == null ? '' : ' $itemName';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: 'Decrease$name',
            onPressed: onDecrease,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTypography.amount,
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'Increase$name',
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: AppColors.textPrimary,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
    );
  }
}

/// A label and amount on one line, as in a receipt. [emphasized] is the
/// total; [valueColor] marks amounts still owed.
class SummaryLine extends StatelessWidget {
  const SummaryLine({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final labelText = Text(
      label,
      style: (emphasized ? textTheme.titleSmall : textTheme.bodyMedium)
          ?.copyWith(
            color: emphasized ? AppColors.textPrimary : AppColors.textSecondary,
          ),
    );
    final valueText = Text(
      value,
      maxLines: 1,
      style: (emphasized ? AppTypography.metricMedium : AppTypography.amount)
          .copyWith(color: valueColor ?? AppColors.textPrimary),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(child: labelText),
            const SizedBox(width: AppSpacing.md),
            // Right-aligned, and shrinks rather than overflows on very
            // narrow panels.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.65,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: valueText,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The bar pinned under a phone checkout: what is being paid and the one
/// action that finishes it. Sits in the body so it rises with the keyboard.
class CheckoutBar extends StatelessWidget {
  const CheckoutBar({
    super.key,
    required this.label,
    required this.amount,
    required this.action,
    this.caption,
    this.captionColor,
  });

  /// e.g. "Total · 3 items".
  final String label;
  final String amount;

  /// e.g. "Change GHS 5.00", shown under the amount.
  final String? caption;
  final Color? captionColor;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final caption = this.caption;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        amount,
                        maxLines: 1,
                        style: AppTypography.metricMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Never clipped: the caption can be the change due.
                    if (caption != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          caption,
                          maxLines: 1,
                          style: textTheme.bodySmall?.copyWith(
                            color: captionColor ?? AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // The action never takes more than ~60% of the bar, so the
              // amount always stays readable.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.6,
                ),
                child: action,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled set of single-choice chips that wrap onto more lines, for
/// short option lists such as payment methods. [options] are
/// (value, label) pairs; a null [onSelected] makes the group read-only.
class OptionChipGroup extends StatelessWidget {
  const OptionChipGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final onSelected = this.onSelected;

    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (value, text) in options)
                AppFilterChip(
                  label: text,
                  selected: value == selected,
                  onSelected: onSelected == null
                      ? () {}
                      : () => onSelected(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
