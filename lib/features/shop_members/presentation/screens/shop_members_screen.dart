import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/shop_member.dart';
import '../../domain/entities/shop_members_exception.dart';
import '../providers/shop_members_providers.dart';
import '../widgets/add_shop_attendant_form.dart';
import '../widgets/shop_member_card.dart';

/// Users & Permissions: the owner adds Shop Attendant logins and suspends,
/// restores or revokes their access.
///
/// Only the shop owner reaches this screen (see the router), and the
/// database and the Edge Function reject every call from anyone else.
class ShopMembersScreen extends ConsumerStatefulWidget {
  const ShopMembersScreen({super.key});

  @override
  ConsumerState<ShopMembersScreen> createState() => _ShopMembersScreenState();
}

class _ShopMembersScreenState extends ConsumerState<ShopMembersScreen> {
  /// The member whose change is in flight; every action waits for it.
  String? _busyUserId;

  bool _isAdding = false;

  Future<void> _add() async {
    if (_isAdding || _busyUserId != null) return;
    _isAdding = true;
    try {
      final created = await showAddShopAttendantForm(context);
      if (created == null || !mounted) return;

      ref.invalidate(shopMembersProvider);
      _showMessage(
        created.confirmationEmailSent
            ? 'Shop attendant created. A confirmation email has been sent to '
                  '${created.email}.'
            : "Shop attendant created, but the confirmation email couldn't "
                  'be sent. They can resend it from the sign-in screen.',
      );
    } finally {
      _isAdding = false;
    }
  }

  Future<void> _run(ShopMember member, ShopMemberAction action) async {
    if (_busyUserId != null || member.isOwner) return;

    final confirmed = await _confirm(member, action);
    if (confirmed != true || !mounted || _busyUserId != null) return;

    setState(() => _busyUserId = member.userId);
    try {
      await switch (action) {
        ShopMemberAction.suspend =>
          ref.read(suspendShopMemberProvider).call(member.userId),
        ShopMemberAction.restore =>
          ref.read(restoreShopMemberProvider).call(member.userId),
        ShopMemberAction.revoke =>
          ref.read(revokeShopMemberProvider).call(member.userId),
      };
      ref.invalidate(shopMembersProvider);
      _showMessage(switch (action) {
        ShopMemberAction.suspend => "${member.label}'s access is suspended.",
        ShopMemberAction.restore => "${member.label}'s access is restored.",
        ShopMemberAction.revoke =>
          "${member.label}'s access to your shop is revoked.",
      });
    } on ShopMembersException catch (error) {
      switch (error.kind) {
        // The member moved or vanished under us: show the current list.
        case ShopMembersErrorKind.statusChanged:
        case ShopMembersErrorKind.notFound:
          ref.invalidate(shopMembersProvider);
        // This account may no longer be the owner: let the router re-check.
        case ShopMembersErrorKind.permissionDenied:
          ref.invalidate(shopAccessProvider);
        default:
          break;
      }
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(ShopMembersErrorKind.actionFailed.message, isError: true);
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<bool?> _confirm(ShopMember member, ShopMemberAction action) {
    final (title, message) = switch (action) {
      ShopMemberAction.suspend => (
        'Suspend access for ${member.label}?',
        'The attendant will no longer be able to access this shop until '
            'their access is restored.',
      ),
      ShopMemberAction.restore => (
        'Restore access for ${member.label}?',
        "This will restore the attendant's access to this shop.",
      ),
      ShopMemberAction.revoke => (
        'Revoke access for ${member.label}?',
        "Revoking removes this attendant's access to your shop. Their "
            'ShopMate account is not deleted.',
      ),
    };
    final isDestructive = action != ShopMemberAction.restore;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (action == ShopMemberAction.revoke) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'They leave this list, and the same email cannot be added '
                'again as a new attendant. If this is temporary, suspend '
                'access instead.',
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(action.label),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/more');
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(shopMembersProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
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

            final header = Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                Breakpoints.of(width).isCompact
                    ? AppSpacing.md
                    : AppSpacing.xxl,
                horizontal,
                AppSpacing.xl,
              ),
              child: PageHeader(
                title: 'Users & Permissions',
                subtitle:
                    'Give the people who work in your shop their own login. '
                    'Attendants get the day-to-day shop tools; expenses, '
                    'reports, settings and Users & Permissions stay with you.',
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _leave,
                ),
                actions: [
                  if (members.hasValue)
                    PrimaryButton(
                      label: 'Add Shop Attendant',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: _add,
                    ),
                ],
              ),
            );

            return members.when(
              loading: () => ListView(
                children: [
                  header,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: Semantics(
                      container: true,
                      label: 'Loading shop users',
                      // Replaces the skeleton's generic "Loading" label.
                      child: const ExcludeSemantics(
                        child: SkeletonList(rows: 3),
                      ),
                    ),
                  ),
                ],
              ),
              error: (error, _) => ListView(
                children: [
                  header,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: SurfaceCard(
                      child: ErrorState(
                        compact: true,
                        icon: Icons.cloud_off_rounded,
                        title: 'Unable to load shop users',
                        message: error is ShopMembersException
                            ? error.message
                            : ShopMembersErrorKind.loadFailed.message,
                        retryLabel: 'Retry',
                        onRetry: () => ref.invalidate(shopMembersProvider),
                      ),
                    ),
                  ),
                ],
              ),
              data: (items) => RefreshIndicator(
                onRefresh: () => ref.refresh(shopMembersProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  children: [
                    header,
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      child: _MemberList(
                        members: items,
                        currentUserId: currentUserId,
                        busyUserId: _busyUserId,
                        onAction: _run,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The owner, then the attendants, each as rows in one bordered section.
class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.currentUserId,
    required this.busyUserId,
    required this.onAction,
  });

  final List<ShopMember> members;
  final String? currentUserId;
  final String? busyUserId;
  final void Function(ShopMember member, ShopMemberAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final owners = [
      for (final member in members)
        if (member.isOwner) member,
    ];
    final attendants = [
      for (final member in members)
        if (!member.isOwner) member,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (owners.isNotEmpty) ...[
          const SectionHeader(title: 'Shop owner'),
          const SizedBox(height: AppSpacing.md),
          _Rows(children: [for (final member in owners) _row(member)]),
          const SizedBox(height: AppSpacing.xxl),
        ],
        SectionHeader(
          title: attendants.isEmpty
              ? 'Shop attendants'
              : 'Shop attendants (${attendants.length})',
        ),
        const SizedBox(height: AppSpacing.md),
        if (attendants.isEmpty)
          const SurfaceCard(
            child: EmptyState(
              compact: true,
              icon: Icons.group_add_outlined,
              title: 'No shop attendants yet',
              message:
                  'Add a Shop Attendant to give someone who works in your '
                  'shop their own login.',
            ),
          )
        else
          _Rows(children: [for (final member in attendants) _row(member)]),
      ],
    );
  }

  Widget _row(ShopMember member) {
    return ShopMemberCard(
      key: ValueKey(member.memberId),
      member: member,
      isCurrentUser: member.userId == currentUserId,
      isBusy: busyUserId == member.userId,
      isLocked: busyUserId != null,
      onAction: onAction,
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const RowDivider(),
            children[i],
          ],
        ],
      ),
    );
  }
}
