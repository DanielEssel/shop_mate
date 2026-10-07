import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/shop_member.dart';

/// The access changes an owner can make to an attendant.
enum ShopMemberAction {
  suspend('Suspend access'),
  restore('Restore access'),
  revoke('Revoke access');

  const ShopMemberAction(this.label);

  final String label;
}

/// One shop member. Access actions are offered only for an attendant who is
/// not the signed-in account; the owner never gets controls over
/// themselves, and the database refuses such changes regardless.
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

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final email = member.email;
    final showEmail = email != null && email != member.label;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Initial(label: member.label, isOwner: member.isOwner),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrentUser ? '${member.label} (You)' : member.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (showEmail) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _Chip(
                          label: member.isOwner
                              ? 'Shop Owner'
                              : 'Shop Attendant',
                          color: member.isOwner
                              ? AppColors.primary
                              : AppColors.info,
                          background: member.isOwner
                              ? AppColors.primaryLight
                              : AppColors.infoLight,
                        ),
                        if (member.isActive)
                          const _Chip(
                            label: 'Active',
                            color: AppColors.success,
                            background: AppColors.successLight,
                          )
                        else
                          const _Chip(
                            label: 'Suspended',
                            color: AppColors.error,
                            background: AppColors.errorLight,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_canManage) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: isLocked
                      ? null
                      : () => onAction(member, ShopMemberAction.revoke),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: Text(ShopMemberAction.revoke.label),
                ),
                _statusButton(),
              ],
            ),
          ],
        ],
      ),
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

    return action == ShopMemberAction.suspend
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: Text(action.label),
          )
        : FilledButton.icon(
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
          color: isOwner ? AppColors.primaryLight : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          initial,
          style: AppTypography.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: isOwner ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
