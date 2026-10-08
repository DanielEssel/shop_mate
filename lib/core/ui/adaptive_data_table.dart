import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'layout/breakpoints.dart';
import 'surfaces.dart';

/// One column of an [SliverAdaptiveDataTable].
@immutable
class DataColumnSpec<T> {
  const DataColumnSpec({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.numeric = false,
    this.compare,
    this.visibleFrom = WindowSize.medium,
  });

  final String label;
  final Widget Function(T row) cell;

  /// Share of the row width.
  final int flex;

  /// Right-aligns the header and cells (amounts, quantities).
  final bool numeric;

  /// Enables sorting by this column.
  final int Function(T a, T b)? compare;

  /// The narrowest content width class that shows this column. Lower-priority
  /// columns use [WindowSize.expanded] so they drop out on tablets.
  final WindowSize visibleFrom;
}

/// A list that is a table from [tableFrom] width up and compact rows below.
///
/// It is a sliver so long lists stay lazy; use it inside a
/// `CustomScrollView`. The caller handles the empty case.
class SliverAdaptiveDataTable<T> extends StatefulWidget {
  const SliverAdaptiveDataTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.compactRowBuilder,
    this.onRowTap,
    this.tableFrom = WindowSize.medium,
    this.initialSortColumn,
    this.initialSortAscending = true,
  });

  final List<T> rows;
  final List<DataColumnSpec<T>> columns;

  /// The phone presentation of a row.
  final Widget Function(BuildContext context, T row) compactRowBuilder;

  final ValueChanged<T>? onRowTap;
  final WindowSize tableFrom;

  /// Index into [columns]; must have a `compare`.
  final int? initialSortColumn;
  final bool initialSortAscending;

  @override
  State<SliverAdaptiveDataTable<T>> createState() =>
      _SliverAdaptiveDataTableState<T>();
}

class _SliverAdaptiveDataTableState<T>
    extends State<SliverAdaptiveDataTable<T>> {
  late int? _sortColumn = widget.initialSortColumn;
  late bool _ascending = widget.initialSortAscending;

  List<T> get _sortedRows {
    final column = _sortColumn;
    if (column == null || column >= widget.columns.length) return widget.rows;
    final compare = widget.columns[column].compare;
    if (compare == null) return widget.rows;

    final sorted = List<T>.of(widget.rows);
    sorted.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    return sorted;
  }

  void _toggleSort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.of(constraints.crossAxisExtent);
        final rows = _sortedRows;

        if (size.index < widget.tableFrom.index) {
          return _framed(
            SliverList.separated(
              itemCount: rows.length,
              itemBuilder: (context, index) => _rowMaterial(
                index: index,
                count: rows.length,
                child: widget.compactRowBuilder(context, rows[index]),
              ),
              separatorBuilder: (_, _) => const RowDivider(),
            ),
          );
        }

        final columns = [
          for (var i = 0; i < widget.columns.length; i++)
            if (size.index >= widget.columns[i].visibleFrom.index) i,
        ];

        return _framed(
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: _header(context, columns)),
              SliverList.separated(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return _rowMaterial(
                    index: index,
                    count: rows.length,
                    hasHeader: true,
                    child: _tableRow(context, row, columns),
                  );
                },
                separatorBuilder: (_, _) => const RowDivider(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _framed(Widget sliver) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return DecoratedSliver(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
      ),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
        ),
        sliver: sliver,
      ),
    );
  }

  /// Gives each row a Material for ink, clipped at the outer corners.
  Widget _rowMaterial({
    required int index,
    required int count,
    required Widget child,
    bool hasHeader = false,
  }) {
    const corner = Radius.circular(AppRadius.lg);
    final isFirst = index == 0 && !hasHeader;
    final isLast = index == count - 1;

    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.only(
        topLeft: isFirst ? corner : Radius.zero,
        topRight: isFirst ? corner : Radius.zero,
        bottomLeft: isLast ? corner : Radius.zero,
        bottomRight: isLast ? corner : Radius.zero,
      ),
      child: child,
    );
  }

  Widget _header(BuildContext context, List<int> columns) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          for (final i in columns)
            Expanded(
              flex: widget.columns[i].flex,
              child: _HeaderCell(
                label: widget.columns[i].label,
                numeric: widget.columns[i].numeric,
                sorted: _sortColumn == i,
                ascending: _ascending,
                onTap: widget.columns[i].compare == null
                    ? null
                    : () => _toggleSort(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableRow(BuildContext context, T row, List<int> columns) {
    final onRowTap = widget.onRowTap;

    return InkWell(
      onTap: onRowTap == null ? null : () => onRowTap(row),
      hoverColor: AppColors.surfaceSubtle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              for (final i in columns)
                Expanded(
                  flex: widget.columns[i].flex,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: widget.columns[i].numeric
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: widget.columns[i].cell(row),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.numeric,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool numeric;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = sorted ? AppColors.textPrimary : AppColors.textMuted;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      child: Row(
        mainAxisAlignment: numeric
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.overline.copyWith(color: color),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(
              sorted
                  ? (ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: color,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      label: 'Sort by $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: content,
      ),
    );
  }
}
