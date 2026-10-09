import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/ui/brand.dart';

/// Page frame shared by the shop gate screens (register, pending, suspended,
/// unavailable, loading). Mirrors the login/signup look: brand lockup above a
/// bordered card, constrained width, keyboard-safe scrolling.
class ShopGateFrame extends StatelessWidget {
  const ShopGateFrame({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  static const double _maxContentWidth = 440;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandLockup(),

                  const SizedBox(height: AppSpacing.xxl),

                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: child,
                  ),

                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    footer,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The official ShopMate logo and name, centred above the gate content.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return const Center(child: ShopMateBrand(logoSize: 48));
  }
}

/// Optional icon chip, a title and a supporting message.
class GateHeading extends StatelessWidget {
  const GateHeading({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primaryLight,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Color iconColor;
  final Color iconBackground;

  static const double _chipSize = 56;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(
            child: Container(
              width: _chipSize,
              height: _chipSize,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Full-width primary button with a spinner + label while loading.
class GatePrimaryButton extends StatelessWidget {
  const GatePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        textStyle: Theme.of(context).textTheme.titleMedium,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        // Keep the button green (not greyed out) while loading.
        disabledBackgroundColor: isLoading ? AppColors.primary : null,
        disabledForegroundColor: isLoading ? AppColors.textOnPrimary : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: isLoading
            ? Row(
                key: const ValueKey('loading'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(loadingLabel ?? label),
                ],
              )
            : Text(label, key: const ValueKey('label')),
      ),
    );
  }
}

/// Inline error above a form. Takes no space when [message] is null.
class GateErrorBanner extends StatelessWidget {
  const GateErrorBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Semantics(
                liveRegion: true,
                container: true,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// "Signed in as ..." plus a sign-out action. Always available on gate
/// screens so nobody can get stuck signed in to the wrong account.
class SignedInFooter extends ConsumerWidget {
  const SignedInFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.read(authRepositoryProvider).currentUser?.email;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (email != null)
          Text(
            'Signed in as $email',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        // A platform admin may be waiting on their own shop's approval.
        if (ref.watch(isPlatformAdminProvider).isConfirmedAdmin)
          TextButton.icon(
            onPressed: () => context.go('/admin'),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text(
              'Open Platform Admin',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        TextButton(
          onPressed: () => ref.read(authSessionProvider.notifier).signOut(),
          child: const Text(
            'Sign out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
