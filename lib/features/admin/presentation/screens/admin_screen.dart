import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/admin_exception.dart';
import '../../domain/entities/admin_shop.dart';
import '../providers/admin_providers.dart';

/// The status change behind each admin button.
enum _AdminAction {
  approve(
    label: 'Approve',
    pastTense: 'approved',
    from: AdminShopStatus.pending,
    to: AdminShopStatus.active,
    icon: Icons.check_circle_outline_rounded,
    explanation:
        'The owner and their staff get full access to ShopMate right away.',
  ),
  suspend(
    label: 'Suspend',
    pastTense: 'suspended',
    from: AdminShopStatus.active,
    to: AdminShopStatus.suspended,
    icon: Icons.block_rounded,
    explanation:
        "Everyone in this shop loses access until it's reactivated. No data "
        'is deleted.',
  ),
  reactivate(
    label: 'Reactivate',
    pastTense: 'reactivated',
    from: AdminShopStatus.suspended,
    to: AdminShopStatus.active,
    icon: Icons.restart_alt_rounded,
    explanation: 'Everyone in this shop gets their access back.',
  );

  const _AdminAction({
    required this.label,
    required this.pastTense,
    required this.from,
    required this.to,
    required this.icon,
    required this.explanation,
  });

  final String label;
  final String pastTense;
  final AdminShopStatus from;
  final AdminShopStatus to;
  final IconData icon;
  final String explanation;

  static _AdminAction forStatus(AdminShopStatus status) => switch (status) {
    AdminShopStatus.pending => approve,
    AdminShopStatus.active => suspend,
    AdminShopStatus.suspended => reactivate,
  };
}

/// Platform administration: review new shops and control shop access.
///
/// Only confirmed platform admins reach this screen (see the router), and
/// the database rejects every admin call from anyone else.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  /// The shop whose change is in flight; every action waits for it.
  String? _busyShopId;

  Future<void> _run(AdminShop shop, _AdminAction action) async {
    if (_busyShopId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${action.label} ${shop.name}?'),
        content: Text(action.explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: action == _AdminAction.suspend
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(action.label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busyShopId != null) return;

    setState(() => _busyShopId = shop.id);
    try {
      await switch (action) {
        _AdminAction.approve => ref.read(approveShopProvider).call(shop.id),
        _AdminAction.suspend => ref.read(suspendShopProvider).call(shop.id),
        _AdminAction.reactivate =>
          ref.read(reactivateShopProvider).call(shop.id),
      };
      _refresh(action);
      _showMessage('${shop.name} ${action.pastTense}.');
    } on AdminException catch (error) {
      // The shop moved or vanished under us: show the current lists.
      if (error.kind == AdminErrorKind.statusChanged ||
          error.kind == AdminErrorKind.notFound) {
        _refresh(action);
      }
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(AdminErrorKind.actionFailed.message, isError: true);
    } finally {
      if (mounted) setState(() => _busyShopId = null);
    }
  }

  void _refresh(_AdminAction action) {
    ref
      ..invalidate(adminShopsProvider(action.from))
      ..invalidate(adminShopsProvider(action.to))
      // The admin may have changed their own shop.
      ..invalidate(shopAccessProvider);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      // The router sends accounts without an active shop to their gate.
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(isPlatformAdminProvider);

    return DefaultTabController(
      length: AdminShopStatus.values.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leave,
          ),
          title: const Text('Admin'),
          bottom: admin.isConfirmedAdmin
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Pending'),
                    Tab(text: 'Active'),
                    Tab(text: 'Suspended'),
                  ],
                )
              : null,
        ),
        body: SafeArea(
          child: admin.isLoading
              ? const _Centered(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Checking admin access',
                  ),
                )
              : !admin.isConfirmedAdmin
              ? const _Centered(
                  child: _Message(
                    icon: Icons.lock_outline_rounded,
                    title: 'Not available',
                    message: 'This area is only for ShopMate platform admins.',
                  ),
                )
              : TabBarView(
                  children: [
                    for (final status in AdminShopStatus.values)
                      _ShopList(
                        status: status,
                        busyShopId: _busyShopId,
                        onAction: _run,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ShopList extends ConsumerWidget {
  const _ShopList({
    required this.status,
    required this.busyShopId,
    required this.onAction,
  });

  final AdminShopStatus status;
  final String? busyShopId;
  final void Function(AdminShop shop, _AdminAction action) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(adminShopsProvider(status));

    return shops.when(
      loading: () => _Centered(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading ${status.value} shops',
        ),
      ),
      error: (error, _) => _Centered(
        child: _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load shops',
          message: error is AdminException
              ? error.message
              : AdminErrorKind.loadFailed.message,
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(adminShopsProvider(status)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _Centered(
            child: _Message(
              icon: Icons.storefront_outlined,
              title: switch (status) {
                AdminShopStatus.pending => 'No shops waiting for approval',
                AdminShopStatus.active => 'No active shops',
                AdminShopStatus.suspended => 'No suspended shops',
              },
              message: switch (status) {
                AdminShopStatus.pending =>
                  'New shops appear here after they register.',
                AdminShopStatus.active => 'Approved shops appear here.',
                AdminShopStatus.suspended => 'Suspended shops appear here.',
              },
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminShopsProvider(status).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) return const _Header();
              final shop = items[index - 1];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _ShopCard(
                    shop: shop,
                    isBusy: busyShopId == shop.id,
                    isLocked: busyShopId != null,
                    onAction: onAction,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            'Manage shops and platform access',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.shop,
    required this.isBusy,
    required this.isLocked,
    required this.onAction,
  });

  final AdminShop shop;
  final bool isBusy;
  final bool isLocked;
  final void Function(AdminShop shop, _AdminAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final localizations = MaterialLocalizations.of(context);
    final action = _AdminAction.forStatus(shop.status);
    final approvedAt = shop.approvedAt;
    final phone = shop.phone;

    // Medium dates omit the year; registrations can span years.
    String date(DateTime value) {
      final local = value.toLocal();
      return '${localizations.formatMediumDate(local)}, ${local.year}';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shop.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(status: shop.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Detail(
            icon: Icons.person_outline_rounded,
            text: 'Owner: ${shop.ownerEmail ?? 'Unknown'}',
          ),
          if (phone != null && phone.trim().isNotEmpty)
            _Detail(icon: Icons.phone_outlined, text: phone),
          _Detail(
            icon: Icons.event_outlined,
            text: 'Registered ${date(shop.createdAt)}',
          ),
          if (approvedAt != null)
            _Detail(
              icon: Icons.verified_outlined,
              text: 'Approved ${date(approvedAt)}',
            ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: action == _AdminAction.suspend
                ? OutlinedButton.icon(
                    onPressed: isLocked ? null : () => onAction(shop, action),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    icon: _ActionIcon(isBusy: isBusy, icon: action.icon),
                    label: Text(action.label),
                  )
                : FilledButton.icon(
                    onPressed: isLocked ? null : () => onAction(shop, action),
                    icon: _ActionIcon(isBusy: isBusy, icon: action.icon),
                    label: Text(action.label),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.isBusy, required this.icon});

  final bool isBusy;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!isBusy) return Icon(icon, size: 18);
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        semanticsLabel: 'Updating shop',
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AdminShopStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      AdminShopStatus.pending => (
        'Pending',
        AppColors.warning,
        AppColors.warningLight,
      ),
      AdminShopStatus.active => (
        'Active',
        AppColors.success,
        AppColors.successLight,
      ),
      AdminShopStatus.suspended => (
        'Suspended',
        AppColors.error,
        AppColors.errorLight,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 16, color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: child,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final action = this.action;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: 40, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (action != null) ...[const SizedBox(height: AppSpacing.lg), action],
      ],
    );
  }
}
