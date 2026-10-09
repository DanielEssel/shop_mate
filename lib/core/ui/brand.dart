import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The official ShopMate application logo (the green SM cube on navy).
///
/// This identifies the ShopMate app itself. It is never a shop's own
/// uploaded logo: shops are shown with `ShopLogoMark`.
class ShopMateLogo extends StatelessWidget {
  const ShopMateLogo({super.key, this.size = 48});

  static const asset = 'assets/Shopmate_icon.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'ShopMate logo',
      child: ClipRRect(
        // Rounded like a launcher icon; the artwork itself is unchanged.
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          // Never leave a gap: the navy tile stands in if the asset fails.
          errorBuilder: (_, _, _) => SizedBox.square(
            dimension: size,
            child: const ColoredBox(color: _logoBackground),
          ),
        ),
      ),
    );
  }

  /// The navy of the logo artwork.
  static const _logoBackground = Color(0xFF19232C);
}

/// The ShopMate logo with the product name beside it, for app-level brand
/// headers (sign-in, sign-up, shop status screens).
class ShopMateBrand extends StatelessWidget {
  const ShopMateBrand({super.key, this.onDark = false, this.logoSize = 44});

  /// White name for dark or green surfaces.
  final bool onDark;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'ShopMate',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(logoSize * 0.22),
                // A hairline keeps the navy tile distinct on dark surfaces.
                border: Border.all(
                  color: onDark
                      ? AppColors.textOnPrimary.withValues(alpha: 0.18)
                      : AppColors.border,
                ),
              ),
              child: ShopMateLogo(size: logoSize),
            ),
            SizedBox(width: logoSize * 0.3 < 12 ? 12 : logoSize * 0.3),
            Flexible(
              child: Text(
                'ShopMate',
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: onDark
                      ? AppColors.textOnPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
