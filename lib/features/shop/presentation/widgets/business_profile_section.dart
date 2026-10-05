import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/shop_branding_exception.dart';
import '../../domain/entities/shop_branding_result.dart';
import '../../domain/entities/shop_logo_upload.dart';
import '../providers/shop_branding_providers.dart';
import '../providers/shop_logo_picker_provider.dart';
import '../providers/shop_provider.dart';
import '../utils/shop_branding_messages.dart';

enum _BusyAction { none, uploading, removing }

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
        borderRadius: BorderRadius.circular(AppRadius.md),
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
  });

  final ShopBrandingResult result;
  final bool isOwner;
  final _BusyAction busy;
  final VoidCallback onChangeLogo;
  final VoidCallback onRemoveLogo;

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
            busy == _BusyAction.uploading
                ? 'Updating logo...'
                : 'Removing logo...',
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
        _InfoRow(label: 'Shop name', value: branding.name),
        _InfoRow(label: 'Phone', value: branding.phone),
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
          if (busy != _BusyAction.none)
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
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
        ],
      ),
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
