import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The platform files that decide what users see as the app's name and
/// icon. Runs from the project root, like every `flutter test`.
String _read(String path) => File(path).readAsStringSync();

/// Width, height and PNG colour type (2 = RGB, 6 = RGBA).
(int, int, int) _pngInfo(String path) {
  final bytes = File(path).readAsBytesSync();
  final view = ByteData.sublistView(bytes);
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: path);
  return (view.getUint32(16), view.getUint32(20), bytes[25]);
}

void main() {
  group('product name is ShopMate', () {
    test('Flutter app title', () {
      expect(_read('lib/app/app.dart'), contains("title: 'ShopMate'"));
    });

    test('Android launcher label, with the app id untouched', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:label="ShopMate"'));
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    });

    test('iOS display and bundle names, bundle id still from the build', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(
        plist,
        contains('<key>CFBundleDisplayName</key>\n\t<string>ShopMate</string>'),
      );
      expect(
        plist,
        contains('<key>CFBundleName</key>\n\t<string>ShopMate</string>'),
      );
      expect(plist, contains(r'<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>'));
    });

    test('Windows window title and product metadata', () {
      expect(
        _read('windows/runner/main.cpp'),
        contains('window.Create(L"ShopMate", origin, size)'),
      );
      final rc = _read('windows/runner/Runner.rc');
      expect(rc, contains('VALUE "ProductName", "ShopMate"'));
      expect(rc, contains('VALUE "FileDescription", "ShopMate"'));
      // The executable keeps its technical name.
      expect(rc, contains('VALUE "OriginalFilename", "shopmate.exe"'));
    });
  });

  group('app icons use the official ShopMate logo', () {
    test('the in-app logo asset is registered', () {
      expect(_read('pubspec.yaml'), contains('- assets/Shopmate_icon.png'));
      final (w, h, _) = _pngInfo('assets/Shopmate_icon.png');
      expect((w, h), (256, 256));
    });

    test('Windows runner embeds app_icon.ico', () {
      expect(
        _read('windows/runner/Runner.rc'),
        contains(
          r'IDI_APP_ICON            ICON                    "resources\\app_icon.ico"',
        ),
      );
      expect(
        File('windows/runner/resources/app_icon.ico').existsSync(),
        isTrue,
      );
    });

    test('Android has a launcher icon at every density', () {
      for (final (density, px) in [
        ('mdpi', 48),
        ('hdpi', 72),
        ('xhdpi', 96),
        ('xxhdpi', 144),
        ('xxxhdpi', 192),
      ]) {
        final (w, h, _) = _pngInfo(
          'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        );
        expect((w, h), (px, px), reason: density);
      }
    });

    test(
      'every iOS icon in Contents.json exists at its exact size, opaque',
      () {
        const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
        final contents =
            jsonDecode(_read('$dir/Contents.json')) as Map<String, dynamic>;
        final images = (contents['images'] as List)
            .cast<Map<String, dynamic>>();
        expect(images, isNotEmpty);

        for (final image in images) {
          final filename = image['filename'] as String;
          final points = double.parse(
            (image['size'] as String).split('x').first,
          );
          final scale = int.parse(
            (image['scale'] as String).replaceAll('x', ''),
          );
          final expected = (points * scale).round();

          final (w, h, colorType) = _pngInfo('$dir/$filename');
          expect((w, h), (expected, expected), reason: filename);
          // App Store icons must not have an alpha channel.
          expect(colorType, 2, reason: '$filename must be RGB, no alpha');
        }
      },
    );
  });
}
