import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../providers/shop_provider.dart';
import '../widgets/shop_gate_frame.dart';

/// Shown after a shop is registered, until an admin activates it.
/// Re-checks on its own every 30 seconds, or on demand.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  static const Duration _pollInterval = Duration(seconds: 30);

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) {
        ref.invalidate(shopAccessProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(shopAccessProvider);
    final shopName = access.value?.shopName;

    final subject = shopName == null ? 'Your shop' : 'Your shop, $shopName,';

    return ShopGateFrame(
      footer: const SignedInFooter(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GateHeading(
            icon: Icons.hourglass_top_rounded,
            title: 'Waiting for approval',
            message:
                '$subject has been submitted. We review every new shop '
                "before it goes live, and you'll get full access as soon as "
                "it's approved. This page checks automatically.",
          ),

          const SizedBox(height: AppSpacing.xxl),

          GatePrimaryButton(
            label: 'Check status',
            loadingLabel: 'Checking…',
            isLoading: access.isLoading,
            onPressed: () => ref.invalidate(shopAccessProvider),
          ),
        ],
      ),
    );
  }
}

/// Shown when the shop, or this user's membership, has been suspended.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(shopAccessProvider);

    return ShopGateFrame(
      footer: const SignedInFooter(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GateHeading(
            icon: Icons.block_rounded,
            iconColor: AppColors.error,
            iconBackground: AppColors.errorLight,
            title: 'Access suspended',
            message:
                'Your ShopMate access is currently suspended. '
                'Please contact support to have it restored.',
          ),

          const SizedBox(height: AppSpacing.xxl),

          GatePrimaryButton(
            label: 'Check again',
            loadingLabel: 'Checking…',
            isLoading: access.isLoading,
            onPressed: () => ref.invalidate(shopAccessProvider),
          ),
        ],
      ),
    );
  }
}

/// Shown when the account status could not be loaded (usually offline).
class AccessErrorScreen extends ConsumerWidget {
  const AccessErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(shopAccessProvider);

    return ShopGateFrame(
      footer: const SignedInFooter(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GateHeading(
            icon: Icons.wifi_off_rounded,
            iconColor: AppColors.warning,
            iconBackground: AppColors.warningLight,
            title: "Can't check your account",
            message:
                "We couldn't reach ShopMate. Check your internet "
                'connection and try again.',
          ),

          const SizedBox(height: AppSpacing.xxl),

          GatePrimaryButton(
            label: 'Try again',
            loadingLabel: 'Trying…',
            isLoading: access.isLoading,
            onPressed: () => ref.invalidate(shopAccessProvider),
          ),
        ],
      ),
    );
  }
}

/// Brief splash while the app works out what the signed-in account may access.
class AccessLoadingScreen extends StatelessWidget {
  const AccessLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShopGateFrame(
      child: Semantics(
        liveRegion: true,
        label: 'Checking your account',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Checking your account…',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
