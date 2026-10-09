import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
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

/// How each status reads in tabs, badges and list headings.
extension on AdminShopStatus {
  String get label => switch (this) {
    AdminShopStatus.pending => 'Pending',
    AdminShopStatus.active => 'Active',
    AdminShopStatus.suspended => 'Suspended',
  };

  Widget badge() => switch (this) {
    AdminShopStatus.pending => const StatusBadge(
      label: 'Pending',
      tone: StatusTone.warning,
      icon: Icons.hourglass_top_rounded,
    ),
    AdminShopStatus.active => const StatusBadge(
      label: 'Active',
      tone: StatusTone.success,
      icon: Icons.check_circle_outline_rounded,
    ),
    AdminShopStatus.suspended => const StatusBadge(
      label: 'Suspended',
      tone: StatusTone.danger,
      icon: Icons.block_rounded,
    ),
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

    final confirmed = await showConfirmDialog(
      context,
      title: '${action.label} ${shop.name}?',
      message: action.explanation,
      confirmLabel: action.label,
      destructive: action == _AdminAction.suspend,
    );
    if (!confirmed || !mounted || _busyShopId != null) return;

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
    showFloatingMessage(
      context,
      message,
      backgroundColor: isError ? AppColors.error : AppColors.success,
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
    final confirmed = admin.isConfirmedAdmin;

    return DefaultTabController(
      length: AdminShopStatus.values.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontal = Breakpoints.pagePadding(
                width,
                maxWidth: ContentWidth.standard,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      Breakpoints.of(width).isCompact
                          ? AppSpacing.md
                          : AppSpacing.xxl,
                      horizontal,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PageHeader(
                          title: 'Platform Admin',
                          subtitle: 'Manage shops and platform access',
                          leading: IconButton(
                            tooltip: 'Back',
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: _leave,
                          ),
                        ),
                        if (confirmed) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const _PlatformScopeNotice(),
                          const SizedBox(height: AppSpacing.md),
                          const _StatusTabs(),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: admin.isLoading
                        ? _Centered(
                            child: Semantics(
                              container: true,
                              label: 'Checking admin access',
                              child: const ExcludeSemantics(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          )
                        : !confirmed
                        ? const _Centered(
                            child: SurfaceCard(
                              child: EmptyState(
                                compact: true,
                                icon: Icons.lock_outline_rounded,
                                title: 'Not available',
                                message:
                                    'This area is only for ShopMate platform '
                                    'admins.',
                              ),
                            ),
                          )
                        : TabBarView(
                            children: [
                              for (final status in AdminShopStatus.values)
                                _ShopList(
                                  status: status,
                                  horizontal: horizontal,
                                  busyShopId: _busyShopId,
                                  onAction: _run,
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Makes the elevated scope explicit: these controls act on whole shops
/// across the platform, not on the admin's own shop.
class _PlatformScopeNotice extends StatelessWidget {
  const _PlatformScopeNotice();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.admin_panel_settings_outlined,
              size: 20,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Platform admin. ',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'Changes here apply to whole shops and everyone in '
                        'them, not to your own shop.',
                  ),
                ],
              ),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs();

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.border,
      labelStyle: AppTypography.textTheme.titleSmall,
      unselectedLabelStyle: AppTypography.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: AppSpacing.xxl),
      tabs: [
        for (final status in AdminShopStatus.values) Tab(text: status.label),
      ],
    );
  }
}

class _ShopList extends ConsumerWidget {
  const _ShopList({
    required this.status,
    required this.horizontal,
    required this.busyShopId,
    required this.onAction,
  });

  final AdminShopStatus status;
  final double horizontal;
  final String? busyShopId;
  final void Function(AdminShop shop, _AdminAction action) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(adminShopsProvider(status));

    final Widget content = shops.when(
      loading: () => Semantics(
        container: true,
        label: 'Loading ${status.value} shops',
        child: const ExcludeSemantics(child: SkeletonList(rows: 4)),
      ),
      error: (error, _) => SurfaceCard(
        child: ErrorState(
          compact: true,
          title: 'Unable to load shops',
          message: error is AdminException
              ? error.message
              : AdminErrorKind.loadFailed.message,
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(adminShopsProvider(status)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return SurfaceCard(
            child: EmptyState(
              compact: true,
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${items.length} ${items.length == 1 ? 'shop' : 'shops'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            SurfaceCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    _ShopRow(
                      shop: items[i],
                      isBusy: busyShopId == items[i].id,
                      isLocked: busyShopId != null,
                      onAction: onAction,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminShopsProvider(status).future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          AppSpacing.lg,
          horizontal,
          AppSpacing.xxxl,
        ),
        children: [content],
      ),
    );
  }
}

/// One shop: identity, contact and dates, status and its one action. Wide
/// rows align these in columns; narrow rows stack them.
class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.shop,
    required this.isBusy,
    required this.isLocked,
    required this.onAction,
  });

  final AdminShop shop;
  final bool isBusy;
  final bool isLocked;
  final void Function(AdminShop shop, _AdminAction action) onAction;

  /// From this width the details, status and action sit in columns.
  static const double _columnsFrom = 880;

  /// From this width the action sits beside the details.
  static const double _sideActionFrom = 560;

  static const double _avatar = 40;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final approvedAt = shop.approvedAt;
    final phone = shop.phone;

    // Timestamps: shown as the admin's local calendar day, with the year
    // (registrations can span years).
    String date(DateTime value) => formatShortDate(value.toLocal());

    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialAvatar(name: shop.name, size: _avatar),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shop.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              // Emails have no spaces; let them break rather than clip, so
              // the admin always sees the whole owner address.
              Text(
                'Owner: ${shop.ownerEmail ?? 'Unknown'}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final details = <Widget>[
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
    ];

    final action = _actionButton();
    final status = shop.status.badge();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop: identity, details, status and action in columns.
          if (constraints.maxWidth >= _columnsFrom) {
            return Row(
              children: [
                Expanded(flex: 5, child: identity),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: details,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 120,
                  child: Align(alignment: Alignment.centerLeft, child: status),
                ),
                SizedBox(
                  width: 150,
                  child: Align(alignment: Alignment.centerRight, child: action),
                ),
              ],
            );
          }

          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              Padding(
                padding: const EdgeInsets.only(
                  left: _avatar + AppSpacing.md,
                  top: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    status,
                    const SizedBox(height: AppSpacing.xs),
                    ...details,
                  ],
                ),
              ),
            ],
          );

          // Tablet: the action sits beside the details.
          if (constraints.maxWidth >= _sideActionFrom) {
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: AppSpacing.lg),
                action,
              ],
            );
          }

          // Phone: the action under the details.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        },
      ),
    );
  }

  Widget _actionButton() {
    final action = _AdminAction.forStatus(shop.status);
    final onPressed = isLocked ? null : () => onAction(shop, action);
    final icon = _ActionIcon(isBusy: isBusy, icon: action.icon);

    // Every row has an action, so none is a solid primary button (a list
    // of them would compete). Suspending removes access: styled as a
    // caution.
    final suspend = action == _AdminAction.suspend;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: suspend ? AppColors.error : AppColors.primary,
        side: BorderSide(
          color: suspend ? AppColors.border : AppColors.primary,
        ),
      ),
      icon: icon,
      label: Text(action.label),
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
            child: Icon(icon, size: 15, color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }
}
