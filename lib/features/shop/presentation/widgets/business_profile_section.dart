import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/shop_branding_exception.dart';
import '../../domain/entities/shop_branding_result.dart';
import '../../domain/entities/shop_logo_upload.dart';
import '../../domain/entities/shop_profile_update.dart';
import '../providers/shop_branding_providers.dart';
import '../providers/shop_logo_picker_provider.dart';
import '../providers/shop_provider.dart';
import '../utils/shop_branding_messages.dart';

enum _BusyAction { none, uploading, removing, savingProfile }

/// Shop name, phone and logo. Owners can change or remove the logo; staff
/// see it read-only. The backend remains the authorization boundary.
class BusinessProfileSection extends ConsumerStatefulWidget {
  const BusinessProfileSection({super.key});

  @override
  ConsumerState<BusinessProfileSection> createState() =>
      _BusinessProfileSectionState();
}

class _BusinessProfileSectionState
    extends ConsumerState<BusinessProfileSection> {
  _BusyAction _busy = _BusyAction.none;

  bool get _isBusy => _busy != _BusyAction.none;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _changeLogo() async {
    if (_isBusy) return;

    final picked = await ref.read(shopLogoPickerProvider)();
    if (picked == null || !mounted) return;

    final ShopLogoUpload upload;
    try {
      upload = ShopLogoUpload(
        bytes: await picked.readAsBytes(),
        extension: _extensionOf(picked.name, picked.mimeType),
      );
    } on ShopBrandingException catch (error) {
      if (mounted) _showMessage(shopBrandingErrorMessage(error));
      return;
    }

    if (!mounted) return;
    setState(() => _busy = _BusyAction.uploading);
    try {
      await ref.read(shopBrandingProvider.notifier).uploadLogo(upload);
      if (mounted) _showMessage('Shop logo updated.');
    } on ShopBrandingException catch (error) {
      if (mounted) _showMessage(shopBrandingErrorMessage(error));
    } catch (_) {
      if (mounted) {
        _showMessage("We couldn't update the shop logo. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = _BusyAction.none);
    }
  }

  Future<void> _removeLogo() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove shop logo?'),
          content: const Text(
            'Your shop name will be used instead until you add a new logo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove logo'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = _BusyAction.removing);
    try {
      await ref.read(shopBrandingProvider.notifier).removeLogo();
      if (mounted) _showMessage('Shop logo removed.');
    } on ShopBrandingException catch (error) {
      if (mounted) _showMessage(shopBrandingErrorMessage(error));
    } catch (_) {
      if (mounted) {
        _showMessage("We couldn't remove the shop logo. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = _BusyAction.none);
    }
  }

  Future<void> _editName(ShopBrandingResult result) async {
    if (_isBusy) return;
    final branding = result.branding;

    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EditProfileFieldDialog(
        title: 'Edit business name',
        label: 'Business name',
        initialValue: branding.name,
        textCapitalization: TextCapitalization.words,
        validator: (value) => ShopProfileUpdate.isValidName(value)
            ? null
            : 'Business name must be 2 to 80 characters.',
      ),
    );
    if (value == null || !mounted) return;
    if (value.trim() == branding.name.trim()) return;

    await _saveProfile(name: value, phone: branding.phone);
  }

  Future<void> _editPhone(ShopBrandingResult result) async {
    if (_isBusy) return;
    final branding = result.branding;

    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EditProfileFieldDialog(
        title: 'Edit phone number',
        label: 'Phone number',
        initialValue: branding.phone ?? '',
        helperText: 'Leave blank to remove the phone number.',
        keyboardType: TextInputType.phone,
        validator: (value) {
          final phone = value.trim();
          return phone.isEmpty || ShopProfileUpdate.isValidPhone(phone)
              ? null
              : 'Enter a valid phone number.';
        },
      ),
    );
    if (value == null || !mounted) return;
    if (value.trim() == (branding.phone ?? '').trim()) return;

    await _saveProfile(name: branding.name, phone: value);
  }

  Future<void> _saveProfile({required String name, String? phone}) async {
    final ShopProfileUpdate update;
    try {
      update = ShopProfileUpdate(name: name, phone: phone);
    } on ShopBrandingException catch (error) {
      _showMessage(shopProfileErrorMessage(error));
      return;
    }

    setState(() => _busy = _BusyAction.savingProfile);
    try {
      await ref.read(shopBrandingProvider.notifier).updateProfile(update);
      if (mounted) _showMessage('Business profile updated.');
    } on ShopBrandingException catch (error) {
      if (mounted) _showMessage(shopProfileErrorMessage(error));
    } catch (_) {
      if (mounted) {
        _showMessage(
          "We couldn't save the business profile. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _busy = _BusyAction.none);
    }
  }

  /// The file extension from the picked name, falling back to its MIME type.
  /// [ShopLogoUpload] decides whether it is acceptable.
  static String _extensionOf(String name, String? mimeType) {
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) return name.substring(dot + 1);

    return switch (mimeType) {
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final brandingAsync = ref.watch(shopBrandingProvider);
    final accessLoading = ref.watch(
      shopAccessProvider.select((access) => !access.hasValue),
    );
    final isOwner = ref.watch(
      shopAccessProvider.select((access) => access.value?.isOwner ?? false),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: brandingAsync.when(
        loading: () => const _ProfileLoading(),
        error: (_, _) => _ProfileUnavailable(
          onRetry: () => ref.invalidate(shopBrandingProvider),
        ),
        data: (result) {
          if (result == null) {
            // Branding is null until shop access has resolved.
            if (accessLoading) return const _ProfileLoading();
            return _ProfileUnavailable(
              onRetry: () => ref.invalidate(shopBrandingProvider),
            );
          }

          return _ProfileContent(
            result: result,
            isOwner: isOwner,
            busy: _busy,
            onChangeLogo: _changeLogo,
            onRemoveLogo: _removeLogo,
            onEditName: () => _editName(result),
            onEditPhone: () => _editPhone(result),
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.result,
    required this.isOwner,
    required this.busy,
    required this.onChangeLogo,
    required this.onRemoveLogo,
    required this.onEditName,
    required this.onEditPhone,
  });

  final ShopBrandingResult result;
  final bool isOwner;
  final _BusyAction busy;
  final VoidCallback onChangeLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onEditName;
  final VoidCallback onEditPhone;

  @override
  Widget build(BuildContext context) {
    final branding = result.branding;
    final isBusy = busy != _BusyAction.none;
    final logoFailed = branding.hasLogo && result.logoBytes == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _LogoPreview(
            shopName: branding.name,
            result: result,
            busy: busy,
          ),
        ),
        if (logoFailed) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Logo couldn't be loaded.",
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodySmall!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (isBusy) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            switch (busy) {
              _BusyAction.uploading => 'Updating logo...',
              _BusyAction.removing => 'Removing logo...',
              _ => 'Saving business profile...',
            },
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodySmall!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (isOwner)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: isBusy ? null : onChangeLogo,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Change logo'),
              ),
              if (branding.hasLogo)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onRemoveLogo,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove logo'),
                ),
            ],
          )
        else
          Text(
            'Only the shop owner can change the logo.',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodySmall!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        if (isOwner) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'PNG or JPEG, up to 1 MB.',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodySmall!.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.sm),
        _InfoRow(
          label: 'Business name',
          value: branding.name,
          editLabel: 'Edit business name',
          onEdit: isOwner && !isBusy ? onEditName : null,
          showEdit: isOwner,
        ),
        _InfoRow(
          label: 'Phone',
          value: branding.phone,
          editLabel: 'Edit phone number',
          onEdit: isOwner && !isBusy ? onEditPhone : null,
          showEdit: isOwner,
        ),
      ],
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.shopName,
    required this.result,
    required this.busy,
  });

  final String shopName;
  final ShopBrandingResult result;
  final _BusyAction busy;

  static const _size = 128.0;

  @override
  Widget build(BuildContext context) {
    final bytes = result.logoBytes;
    final trimmed = shopName.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return Semantics(
      image: true,
      label: bytes != null
          ? '$shopName logo'
          : '$shopName has no logo; showing the shop initial',
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _size,
            height: _size,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: bytes != null
                  ? AppColors.surface
                  : AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    key: const ValueKey('shop-logo-image'),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => _Initial(initial: initial),
                  )
                : _Initial(initial: initial),
          ),
          if (busy == _BusyAction.uploading || busy == _BusyAction.removing)
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      key: const ValueKey('shop-logo-fallback'),
      style: AppTypography.textTheme.displayMedium!.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.editLabel,
    this.onEdit,
    this.showEdit = false,
  });

  final String label;
  final String? value;

  /// Accessible description of the Edit action, e.g. "Edit phone number".
  final String? editLabel;

  /// Null disables the Edit button (e.g. while saving).
  final VoidCallback? onEdit;
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    final text = value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SelectableText(
              text ?? 'Not provided',
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: text == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontWeight: text == null ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
          if (showEdit) ...[
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: editLabel,
              excludeSemantics: true,
              child: TextButton(onPressed: onEdit, child: const Text('Edit')),
            ),
          ],
        ],
      ),
    );
  }
}

/// Edits one business profile field. Returns the entered text on Save, or
/// null on Cancel. Saving happens in the section, not in the dialog.
class _EditProfileFieldDialog extends StatefulWidget {
  const _EditProfileFieldDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.validator,
    this.helperText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final String title;
  final String label;
  final String initialValue;
  final String? Function(String value) validator;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  State<_EditProfileFieldDialog> createState() =>
      _EditProfileFieldDialogState();
}

class _EditProfileFieldDialogState extends State<_EditProfileFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
          validator: (value) => widget.validator(value ?? ''),
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helperText,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading shop information',
        ),
      ),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 40,
          color: AppColors.error,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Shop information is temporarily unavailable.',
          textAlign: TextAlign.center,
          style: AppTypography.textTheme.bodyMedium!.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
