import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import 'surfaces.dart';

/// A placeholder block shaped like the content that is loading.
///
/// Static on purpose: it reads as "loading" without a perpetual animation
/// (which also keeps widget tests able to settle).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder rows inside a surface, for lists that are loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6, this.showLeading = true});

  final int rows;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) const RowDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    if (showLeading) ...[
                      const SkeletonBox(
                        width: 36,
                        height: 36,
                        radius: AppRadius.md,
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: i.isEven ? 0.55 : 0.4,
                            child: const SkeletonBox(height: 12),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FractionallySizedBox(
                            widthFactor: i.isEven ? 0.3 : 0.38,
                            child: const SkeletonBox(height: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    const SkeletonBox(width: 64, height: 12),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A full page of loading placeholders: header lines and a list.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.padding, this.rows = 6});

  final EdgeInsetsGeometry? padding;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 180, height: 22),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(width: 240, height: 12),
          const SizedBox(height: AppSpacing.xxl),
          const SkeletonBox(height: 44, radius: AppRadius.md),
          const SizedBox(height: AppSpacing.lg),
          SkeletonList(rows: rows),
        ],
      ),
    );
  }
}
