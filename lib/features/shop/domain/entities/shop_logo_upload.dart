import 'package:flutter/foundation.dart';

import 'shop_branding_exception.dart';

/// A validated logo image ready to upload. Mirrors the `shop-branding`
/// bucket rules (PNG or JPEG, at most 1 MiB); the bucket stays authoritative.
@immutable
class ShopLogoUpload {
  const ShopLogoUpload._({required this.bytes, required this.extension});

  /// Validates [bytes] and [extension] (with or without a leading dot, any
  /// case). Throws [ShopBrandingException] when the image is unacceptable.
  factory ShopLogoUpload({
    required Uint8List bytes,
    required String extension,
  }) {
    var normalized = extension.trim().toLowerCase();
    if (normalized.startsWith('.')) normalized = normalized.substring(1);

    if (!_extensions.contains(normalized)) {
      throw const ShopBrandingException(ShopBrandingErrorKind.invalidFormat);
    }
    if (bytes.isEmpty) {
      throw const ShopBrandingException(ShopBrandingErrorKind.emptyFile);
    }
    if (bytes.length > maxBytes) {
      throw const ShopBrandingException(ShopBrandingErrorKind.tooLarge);
    }

    final isPng = normalized == 'png';
    if (!(isPng ? _hasPngSignature(bytes) : _hasJpegSignature(bytes))) {
      throw const ShopBrandingException(ShopBrandingErrorKind.invalidFormat);
    }

    return ShopLogoUpload._(bytes: bytes, extension: normalized);
  }

  /// Bucket limit: 1 MiB.
  static const maxBytes = 1048576;

  static const _extensions = {'png', 'jpg', 'jpeg'};

  final Uint8List bytes;

  /// Lower-case `png`, `jpg` or `jpeg`.
  final String extension;

  String get contentType => extension == 'png' ? 'image/png' : 'image/jpeg';

  static bool _hasPngSignature(Uint8List bytes) {
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  static bool _hasJpegSignature(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }
}
