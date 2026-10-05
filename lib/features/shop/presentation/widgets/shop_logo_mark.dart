import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';

/// A small, non-interactive shop logo for headers. Shows the logo when
/// [logoBytes] are available, otherwise the shop's initial (or a storefront
/// icon), and a quiet placeholder while [isLoading].
class ShopLogoMark extends StatelessWidget {
  const ShopLogoMark({
    super.key,
    required this.shopName,
    this.logoBytes,
    this.isLoading = false,
    this.size = 48,
  });

  final String? shopName;
  final Uint8List? logoBytes;
  final bool isLoading;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = logoBytes;
    final name = shopName?.trim();
    final hasName = name != null && name.isNotEmpty;

    final String label;
    final Widget child;
    if (bytes != null) {
      label = hasName ? '$name logo' : 'Shop logo';
      child = Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Image.memory(
          bytes,
          key: const ValueKey('shop-logo-mark-image'),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _Fallback(name: name, size: size),
        ),
      );
    } else if (isLoading) {
      label = 'Loading shop logo';
      child = const SizedBox.shrink(key: ValueKey('shop-logo-mark-loading'));
    } else {
      label = hasName ? '$name, no logo' : 'Shop';
      child = _Fallback(name: name, size: size);
    }

    return Semantics(
      image: true,
      label: label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bytes != null
              ? AppColors.surface
              : AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: bytes != null ? Border.all(color: AppColors.border) : null,
        ),
        child: ExcludeSemantics(child: child),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name, required this.size});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    if (name == null || name.isEmpty) {
      return Icon(
        Icons.storefront_outlined,
        key: const ValueKey('shop-logo-mark-fallback'),
        color: AppColors.primary,
        size: size * 0.52,
      );
    }

    return Text(
      name[0].toUpperCase(),
      key: const ValueKey('shop-logo-mark-fallback'),
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.45,
        height: 1,
      ),
    );
  }
}
