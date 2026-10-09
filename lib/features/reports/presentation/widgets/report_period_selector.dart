import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/report_date_range.dart';
import '../providers/report_period_provider.dart';

/// Formats an inclusive range for display, e.g. "Oct 4, 2026" or
/// "Sep 28, 2026 – Oct 4, 2026".
String formatReportRange(BuildContext context, ReportDateRange range) {
  final localizations = MaterialLocalizations.of(context);
  final start = localizations.formatShortDate(range.start);
  if (range.start == range.end) return start;

  return '$start – ${localizations.formatShortDate(range.end)}';
}

/// Today / Last 7 days / Last 30 days / Custom as filter chips, plus the
/// resolved range (and a Change action for a custom range).
class ReportPeriodSelector extends ConsumerWidget {
  const ReportPeriodSelector({super.key});

  /// Earliest selectable date, matching the expense date pickers.
  static final _firstDate = DateTime(2020);

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final current = ref.read(reportPeriodProvider).range;
    final today = ReportPeriodNotifier.today();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: _firstDate,
      lastDate: today,
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      helpText: 'Select report period',
    );

    if (picked == null) return;

    ref
        .read(reportPeriodProvider.notifier)
        .selectCustom(ReportDateRange(start: picked.start, end: picked.end));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final preset in ReportPeriodPreset.values)
              AppFilterChip(
                label: preset.label,
                selected: period.preset == preset,
                onSelected: () {
                  if (preset == ReportPeriodPreset.custom) {
                    _pickCustom(context, ref);
                  } else {
                    ref
                        .read(reportPeriodProvider.notifier)
                        .selectPreset(preset);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                formatReportRange(context, period.range),
                style: AppTypography.textTheme.bodyMedium!.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (period.preset == ReportPeriodPreset.custom)
              TextButton.icon(
                onPressed: () => _pickCustom(context, ref),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: const Text('Change'),
              ),
          ],
        ),
      ],
    );
  }
}
