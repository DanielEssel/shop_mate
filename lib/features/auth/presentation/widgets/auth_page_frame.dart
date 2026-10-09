import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/brand.dart';

/// The layout shared by the sign-in, sign-up and password recovery screens.
///
/// Wide windows split into a deep-green ShopMate brand panel (the retail
/// photo under a green tint) beside a plain white form column. Narrower
/// windows put a compact brand band above the form, so the fields stay near
/// the top and little scrolling is needed. The form is at most
/// [maxFormWidth] wide and scrolls above the keyboard.
class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({super.key, required this.child});

  final Widget child;

  static const backgroundAsset = 'assets/images/auth_image.jpeg';

  static const double maxFormWidth = 420;

  /// From this width the brand panel sits beside the form.
  static const double splitFrom = 900;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= splitFrom) {
            return _SplitLayout(child: child);
          }
          return _StackedLayout(child: child);
        },
      ),
    );
  }
}

class _SplitLayout extends StatelessWidget {
  const _SplitLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(flex: 5, child: _BrandPanel()),
        Expanded(
          flex: 6,
          child: SafeArea(
            left: false,
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.huge,
                  vertical: AppSpacing.section,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AuthPageFrame.maxFormWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StackedLayout extends StatelessWidget {
  const _StackedLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    // A taller band on tall screens; never so tall it pushes the form down.
    final bandHeight = (MediaQuery.sizeOf(context).height * 0.24).clamp(
      176.0,
      280.0,
    );

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: bandHeight + topInset,
            child: const _BrandPanel(compact: true),
          ),
          // The form sheet overlaps the band slightly so the two read as one
          // surface rather than a banner above a page.
          Transform.translate(
            offset: const Offset(0, -AppSpacing.xl),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AuthPageFrame.maxFormWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deep-green brand surface: the retail photo, tinted, under the ShopMate
/// lockup. [compact] is the short band used above the form on phones.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  static const _tagline = 'Sales, stock and customers in one place.';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppColors.primaryDeep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative only: crops rather than stretches at any shape.
          ExcludeSemantics(
            child: Opacity(
              opacity: 0.38,
              child: Image.asset(
                AuthPageFrame.backgroundAsset,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Green tint, deepest where the text sits.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDeep.withValues(alpha: 0.55),
                  AppColors.primaryDeep.withValues(
                    alpha: compact ? 0.80 : 0.94,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            right: false,
            bottom: !compact,
            child: Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.xxxl,
                    )
                  : const EdgeInsets.all(AppSpacing.section),
              child: compact
                  // Lines up with the form column below.
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AuthPageFrame.maxFormWidth,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const _BrandLockup(),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _tagline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textOnPrimary.withValues(
                                    alpha: 0.80,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _BrandLockup(logoSize: 64),
                        const Spacer(),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tagline,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: AppColors.textOnPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Record sales, track inventory and follow up '
                                'on credit from the counter or the back office.',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textOnPrimary.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              const _Highlight(
                                icon: Icons.point_of_sale_rounded,
                                label:
                                    'Fast checkout with cash, MoMo or credit',
                              ),
                              const _Highlight(
                                icon: Icons.inventory_2_outlined,
                                label: 'See low stock before shelves run empty',
                              ),
                              const _Highlight(
                                icon: Icons.insights_rounded,
                                label: 'Daily performance at a glance',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The official ShopMate logo and name, in their on-dark colours. Larger
/// on the wide brand panel than in the compact phone band.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.logoSize = 48});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return ShopMateBrand(onDark: true, logoSize: logoSize);
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBright),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title and subtitle at the top of an auth form.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// The full-width call to action at the bottom of an auth form. Stays green
/// with a spinner while [isBusy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;

  /// Announced to screen readers while busy.
  final String busyLabel;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isBusy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        disabledBackgroundColor: isBusy ? AppColors.primary : null,
        disabledForegroundColor: isBusy ? AppColors.textOnPrimary : null,
        textStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: isBusy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textOnPrimary,
                semanticsLabel: busyLabel,
              ),
            )
          : Text(label),
    );
  }
}
