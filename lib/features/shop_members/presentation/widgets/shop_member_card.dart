import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/shop_member.dart';

/// The access changes an owner can make to an attendant.
enum ShopMemberAction {
  suspend('Suspend access'),
  restore('Restore access'),
  revoke('Revoke access');

  const ShopMemberAction(this.label);

  final String label;
}

/// One shop member as a row in a bordered list: identity, role, status and
/// (for attendants) the access actions. Wide rows align these in columns;
/// narrow rows stack the actions under the identity.
///
/// Access actions are offered only for an attendant who is not the
/// signed-in account; the owner never gets controls over themselves, and
/// the database refuses such changes regardless.
class ShopMemberCard extends StatelessWidget {
  const ShopMemberCard({
    super.key,
    required this.member,
    required this.isCurrentUser,
    required this.isBusy,
    required this.isLocked,
    required this.onAction,
  });

  final ShopMember member;
  final bool isCurrentUser;

  /// This member's change is in flight.
  final bool isBusy;

  /// Some change is in flight; every action waits for it.
  final bool isLocked;

  final void Function(ShopMember member, ShopMemberAction action) onAction;

  bool get _canManage => !member.isOwner && !isCurrentUser;

  /// From this width the role, status and actions sit in columns.
  static const double _columnsFrom = 880;

  /// From this width the actions sit beside the identity.
  static const double _sideActionsFrom = 560;

  @override
  Widget build(BuildContext context) {
    final email = member.email;
    final showEmail = email != null && email != member.label;

    final identity = Row(
      children: [
        _Initial(label: member.label, isOwner: member.isOwner),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCurrentUser ? '${member.label} (You)' : member.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (showEmail) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final role = StatusBadge(
      label: member.isOwner ? 'Shop Owner' : 'Shop Attendant',
      tone: member.isOwner ? StatusTone.brand : StatusTone.neutral,
      icon: member.isOwner
          ? Icons.workspace_premium_outlined
          : Icons.badge_outlined,
    );

    final status = member.isActive
        ? const StatusBadge(
            label: 'Active',
            tone: StatusTone.success,
            icon: Icons.check_circle_outline_rounded,
          )
        : const StatusBadge(
            label: 'Suspended',
            tone: StatusTone.warning,
            icon: Icons.block_rounded,
          );

    final actions = _canManage ? _actions() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final badges = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [role, status],
          );

          // Desktop: identity, role, status and actions in aligned columns.
          if (constraints.maxWidth >= _columnsFrom) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 160,
                  child: Align(alignment: Alignment.centerLeft, child: role),
                ),
                SizedBox(
                  width: 130,
                  child: Align(alignment: Alignment.centerLeft, child: status),
                ),
                // Keeps owner and attendant rows aligned even when only
                // attendants have actions.
                SizedBox(
                  width: 330,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          }

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: 40 + AppSpacing.md),
                child: badges,
              ),
            ],
          );

          // Tablet: the actions sit beside the identity.
          if (constraints.maxWidth >= _sideActionsFrom && actions != null) {
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: AppSpacing.lg),
                actions,
              ],
            );
          }

          // Phone: actions under the identity.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              if (actions != null) ...[
                const SizedBox(height: AppSpacing.md),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Revoke is quieter (and asks first); suspend/restore is the everyday
  /// action.
  Widget _actions() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        TextButton(
          onPressed: isLocked
              ? null
              : () => onAction(member, ShopMemberAction.revoke),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(ShopMemberAction.revoke.label),
        ),
        _statusButton(),
      ],
    );
  }

  Widget _statusButton() {
    final action = member.isActive
        ? ShopMemberAction.suspend
        : ShopMemberAction.restore;
    final icon = isBusy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Updating access',
            ),
          )
        : Icon(
            action == ShopMemberAction.suspend
                ? Icons.block_rounded
                : Icons.restart_alt_rounded,
            size: 18,
          );
    final onPressed = isLocked ? null : () => onAction(member, action);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(action.label),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.label, required this.isOwner});

  final String label;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty
        ? '?'
        : String.fromCharCode(label.trim().runes.first).toUpperCase();

    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isOwner ? AppColors.primarySoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          initial,
          style: AppTypography.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isOwner ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
