import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
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
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
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
          backgroundColor: isError ? AppColors.error : AppColors.success,
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _leave,
        ),
        title: Text(
          'Users & Permissions',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: members.when(
          loading: () => const _Centered(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading shop users',
            ),
          ),
          error: (error, _) => _Centered(
            child: _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load shop users',
              message: error is ShopMembersException
                  ? error.message
                  : ShopMembersErrorKind.loadFailed.message,
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(shopMembersProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ),
          data: (items) => _MemberList(
            members: items,
            currentUserId: currentUserId,
            busyUserId: _busyUserId,
            onAdd: _add,
            onAction: _run,
            onRefresh: () => ref.refresh(shopMembersProvider.future),
          ),
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.currentUserId,
    required this.busyUserId,
    required this.onAdd,
    required this.onAction,
    required this.onRefresh,
  });

  final List<ShopMember> members;
  final String? currentUserId;
  final String? busyUserId;
  final VoidCallback onAdd;
  final void Function(ShopMember member, ShopMemberAction action) onAction;
  final Future<void> Function() onRefresh;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final columns = isDesktop ? 2 : 1;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.md),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(isDesktop: isDesktop, onAdd: onAdd),
                      if (owners.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const _SectionTitle(title: 'Shop owner'),
                        const SizedBox(height: AppSpacing.sm),
                        _CardGrid(
                          columns: columns,
                          children: [
                            for (final member in owners) _card(member),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _SectionTitle(
                        title: attendants.isEmpty
                            ? 'Shop attendants'
                            : 'Shop attendants (${attendants.length})',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (attendants.isEmpty)
                        const _EmptyAttendants()
                      else
                        _CardGrid(
                          columns: columns,
                          children: [
                            for (final member in attendants) _card(member),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(ShopMember member) {
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

class _Header extends StatelessWidget {
  const _Header({required this.isDesktop, required this.onAdd});

  final bool isDesktop;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final description = Text(
      'Give the people who work in your shop their own login. Attendants '
      'get the day-to-day shop tools; expenses, reports, settings and Users '
      '& Permissions stay with you.',
      style: AppTypography.textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
    );
    final button = FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Add Shop Attendant'),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: description),
          const SizedBox(width: AppSpacing.xl),
          button,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        description,
        const SizedBox(height: AppSpacing.md),
        button,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Lays cards out in [columns] equal columns, rows sized to their content.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.md));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var offset = 0; offset < columns; offset++) ...[
                if (offset > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: start + offset < children.length
                      ? children[start + offset]
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
      children: rows,
    );
  }
}

class _EmptyAttendants extends StatelessWidget {
  const _EmptyAttendants();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const _Message(
        icon: Icons.group_add_outlined,
        title: 'No shop attendants yet',
        message:
            'Add a Shop Attendant to give someone who works in your shop '
            'their own login.',
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
