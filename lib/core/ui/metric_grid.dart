import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import 'layout/breakpoints.dart';

/// Lays out a page's key figures ([MetricCard]s): one row on desktop, two
/// columns on phones and tablets (one on small phones). With an odd count on
/// two columns the lead card takes a full row, so put the emphasized card
/// first.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.of(constraints.maxWidth);

        final int columns;
        if (size.isAtLeastExpanded) {
          columns = cards.length;
        } else if (Breakpoints.isSmallPhone(MediaQuery.sizeOf(context).width)) {
          columns = 1;
        } else {
          columns = 2;
        }

        const spacing = AppSpacing.md;
        final leadFullWidth = columns == 2 && cards.length.isOdd;

        final rows = <Widget>[];
        var index = 0;
        if (leadFullWidth) {
          rows.add(cards[index++]);
        }
        while (index < cards.length) {
          final rowCards = cards.skip(index).take(columns).toList();
          index += rowCards.length;
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: spacing),
                    Expanded(
                      child: i < rowCards.length
                          ? rowCards[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: spacing),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}
