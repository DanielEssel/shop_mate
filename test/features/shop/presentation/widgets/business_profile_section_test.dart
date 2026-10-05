import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:shopmate/features/settings/presentation/screens/settings_screen.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_exception.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/domain/entities/shop_logo_upload.dart';
import 'package:shopmate/features/shop/domain/repositories/shop_branding_repository.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_logo_picker_provider.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';

/// A real 1x1 PNG.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Uint8List _oversizedPng() {
  return Uint8List(ShopLogoUpload.maxBytes + 1)..setAll(0, _pngBytes);
}

/// Stands in for the S2 repository, with controllable outcomes.
class _FakeBrandingRepository implements ShopBrandingRepository {
  _FakeBrandingRepository({this.logoPath, this.phone = '0240000001'})
    : logoBytes = logoPath == null ? null : _pngBytes;

  String? logoPath;
  Uint8List? logoBytes;
  String? phone;
  bool logoDownloadFails = false;
  ShopBrandingException? readFailure;
  ShopBrandingException? uploadFailure;
  ShopBrandingException? removeFailure;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  final calls = <String>[];

  ShopBrandingResult _result(String shopId) {
    final failed = logoPath != null && logoDownloadFails;
    return ShopBrandingResult(
      branding: ShopBranding(
        shopId: shopId,
        name: "Danny's Shop",
        phone: phone,
        logoPath: logoPath,
      ),
      logoBytes: failed ? null : logoBytes,
      logoError: failed
          ? const ShopBrandingException(ShopBrandingErrorKind.logoUnavailable)
          : null,
    );
  }

  @override
  Future<ShopBrandingResult> getShopBranding(String shopId) async {
    calls.add('get');
    await readGate?.future;
    final failure = readFailure;
    if (failure != null) throw failure;
    return _result(shopId);
  }

  @override
  Future<ShopBrandingResult> uploadLogo(
    String shopId,
    ShopLogoUpload upload,
  ) async {
    calls.add('upload:${upload.extension}');
    await writeGate?.future;
    final failure = uploadFailure;
    if (failure != null) throw failure;
    logoPath = '$shopId/logo-2.${upload.extension}';
    logoBytes = upload.bytes;
    return _result(shopId);
  }

  @override
  Future<ShopBrandingResult> removeLogo(String shopId) async {
    calls.add('remove');
    await writeGate?.future;
    final failure = removeFailure;
    if (failure != null) throw failure;
    logoPath = null;
    logoBytes = null;
    return _result(shopId);
  }
}

class _Picker {
  XFile? next;
  int opened = 0;

  Future<XFile?> pick() async {
    opened++;
    return next;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeBrandingRepository repository, {
  String role = 'owner',
  _Picker? picker,
  Size size = const Size(420, 1600),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final activePicker = picker ?? _Picker();

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        shopAccessProvider.overrideWith(
          (ref) async => ShopAccess(
            userId: 'user-1',
            status: ShopAccessStatus.active,
            shopId: 'shop-1',
            shopName: "Danny's Shop",
            role: role,
          ),
        ),
        shopBrandingRepositoryProvider.overrideWithValue(repository),
        shopLogoPickerProvider.overrideWithValue(activePicker.pick),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Finder get _changeButton => find.widgetWithText(FilledButton, 'Change logo');
Finder get _removeButton => find.widgetWithText(OutlinedButton, 'Remove logo');
Finder get _logoImage => find.byKey(const ValueKey('shop-logo-image'));
Finder get _fallback => find.byKey(const ValueKey('shop-logo-fallback'));

bool _enabled(WidgetTester tester, Finder button) {
  final widget = tester.widget<ButtonStyleButton>(button);
  return widget.onPressed != null;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('business profile', () {
    testWidgets('shows the shop name and phone', (tester) async {
      await _pump(tester, _FakeBrandingRepository());

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Business Profile'), findsOneWidget);
      expect(find.text("Danny's Shop"), findsOneWidget);
      expect(find.text('0240000001'), findsOneWidget);
    });

    testWidgets('a missing phone shows "Not provided"', (tester) async {
      await _pump(tester, _FakeBrandingRepository(phone: null));

      expect(find.text('Not provided'), findsOneWidget);
    });

    testWidgets('shows the logo when bytes exist', (tester) async {
      await _pump(
        tester,
        _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png'),
      );

      expect(_logoImage, findsOneWidget);
      expect(find.bySemanticsLabel("Danny's Shop logo"), findsOneWidget);
    });

    testWidgets('shows the initial fallback without a logo', (tester) async {
      await _pump(tester, _FakeBrandingRepository());

      expect(_logoImage, findsNothing);
      expect(_fallback, findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('shows a loading state, not a blank screen', (tester) async {
      final repository = _FakeBrandingRepository()
        ..readGate = Completer<void>();
      await _pump(tester, repository, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.text('Business Profile'), findsOneWidget);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.semanticsLabel, 'Loading shop information');
      expect(
        find.text('Shop information is temporarily unavailable.'),
        findsNothing,
      );

      repository.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text("Danny's Shop"), findsOneWidget);
    });

    testWidgets('a logo download failure falls back with a quiet note', (
      tester,
    ) async {
      final repository = _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png')
        ..logoDownloadFails = true;
      await _pump(tester, repository);

      expect(_fallback, findsOneWidget);
      expect(find.text("Logo couldn't be loaded."), findsOneWidget);
      expect(find.text("Danny's Shop"), findsOneWidget);
    });

    testWidgets('unreadable branding shows a safe message and retry', (
      tester,
    ) async {
      final repository = _FakeBrandingRepository()
        ..readFailure = const ShopBrandingException(
          ShopBrandingErrorKind.unavailable,
          cause: 'PGRST raw text',
        );
      await _pump(tester, repository);

      expect(
        find.text('Shop information is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.textContaining('PGRST'), findsNothing);

      repository.readFailure = null;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text("Danny's Shop"), findsOneWidget);
    });
  });

  group('owner vs staff', () {
    testWidgets('owner sees Change and, with a logo, Remove', (tester) async {
      await _pump(
        tester,
        _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png'),
      );

      expect(_changeButton, findsOneWidget);
      expect(_removeButton, findsOneWidget);
    });

    testWidgets('owner without a logo sees no Remove', (tester) async {
      await _pump(tester, _FakeBrandingRepository());

      expect(_changeButton, findsOneWidget);
      expect(_removeButton, findsNothing);
    });

    testWidgets('staff see the logo read-only', (tester) async {
      await _pump(
        tester,
        _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png'),
        role: 'staff',
      );

      expect(_logoImage, findsOneWidget);
      expect(_changeButton, findsNothing);
      expect(_removeButton, findsNothing);
      expect(
        find.text('Only the shop owner can change the logo.'),
        findsOneWidget,
      );
    });
  });

  group('change logo', () {
    testWidgets('upload refreshes the preview and confirms', (tester) async {
      final repository = _FakeBrandingRepository();
      final picker = _Picker()
        ..next = XFile.fromData(
          _pngBytes,
          name: 'my logo.PNG',
          path: 'my logo.PNG',
        );
      await _pump(tester, repository, picker: picker);

      await tester.tap(_changeButton);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('upload:png'));
      expect(find.text('Shop logo updated.'), findsOneWidget);
      expect(_logoImage, findsOneWidget);
      expect(_fallback, findsNothing);
      expect(_removeButton, findsOneWidget);
    });

    testWidgets('actions are disabled while uploading', (tester) async {
      final repository = _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png')
        ..writeGate = Completer<void>();
      final picker = _Picker()
        ..next = XFile.fromData(_pngBytes, name: 'logo.png', path: 'logo.png');
      await _pump(tester, repository, picker: picker);

      await tester.tap(_changeButton);
      await tester.pump();
      await tester.pump();

      expect(find.text('Updating logo...'), findsOneWidget);
      expect(_enabled(tester, _changeButton), isFalse);
      expect(_enabled(tester, _removeButton), isFalse);
      expect(_logoImage, findsOneWidget);

      await tester.tap(_changeButton, warnIfMissed: false);
      expect(picker.opened, 1);

      repository.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(_enabled(tester, _changeButton), isTrue);
      expect(find.text('Updating logo...'), findsNothing);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final repository = _FakeBrandingRepository();
      final picker = _Picker();
      await _pump(tester, repository, picker: picker);

      await tester.tap(_changeButton);
      await tester.pumpAndSettle();

      expect(picker.opened, 1);
      expect(repository.calls, ['get']);
      expect(find.byType(SnackBar), findsNothing);
      expect(_enabled(tester, _changeButton), isTrue);
    });

    testWidgets('an oversized image is rejected before uploading', (
      tester,
    ) async {
      final repository = _FakeBrandingRepository();
      final picker = _Picker()
        ..next = XFile.fromData(
          _oversizedPng(),
          name: 'big.png',
          path: 'big.png',
        );
      await _pump(tester, repository, picker: picker);

      await tester.tap(_changeButton);
      await tester.pumpAndSettle();

      expect(find.text('Logo must be 1 MB or smaller.'), findsOneWidget);
      expect(repository.calls, ['get']);
    });

    testWidgets('an unsupported format is rejected before uploading', (
      tester,
    ) async {
      final repository = _FakeBrandingRepository();
      final picker = _Picker()
        ..next = XFile.fromData(_pngBytes, name: 'logo.gif', path: 'logo.gif');
      await _pump(tester, repository, picker: picker);

      await tester.tap(_changeButton);
      await tester.pumpAndSettle();

      expect(find.text('Choose a PNG or JPEG image.'), findsOneWidget);
      expect(repository.calls, ['get']);
    });

    testWidgets('an upload failure shows a safe message and keeps the logo', (
      tester,
    ) async {
      final repository = _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png')
        ..uploadFailure = const ShopBrandingException(
          ShopBrandingErrorKind.uploadFailed,
          cause: 'StorageException: raw',
        );
      final picker = _Picker()
        ..next = XFile.fromData(_pngBytes, name: 'logo.png', path: 'logo.png');
      await _pump(tester, repository, picker: picker);

      await tester.tap(_changeButton);
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't update the shop logo. Please try again."),
        findsOneWidget,
      );
      expect(find.textContaining('StorageException'), findsNothing);
      expect(_logoImage, findsOneWidget);
      expect(_enabled(tester, _changeButton), isTrue);
    });

    testWidgets('a permission failure gets its own message', (tester) async {
      final repository = _FakeBrandingRepository()
        ..uploadFailure = const ShopBrandingException(
          ShopBrandingErrorKind.permissionDenied,
        );
      final picker = _Picker()
        ..next = XFile.fromData(_pngBytes, name: 'logo.png', path: 'logo.png');
      await _pump(tester, repository, picker: picker);

      await tester.tap(_changeButton);
      await tester.pumpAndSettle();

      expect(
        find.text("You don't have permission to change the shop logo."),
        findsOneWidget,
      );
    });
  });

  group('remove logo', () {
    testWidgets('Cancel in the confirmation does nothing', (tester) async {
      final repository = _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png');
      await _pump(tester, repository);

      await tester.tap(_removeButton);
      await tester.pumpAndSettle();
      expect(find.text('Remove shop logo?'), findsOneWidget);
      expect(
        find.text(
          'Your shop name will be used instead until you add a new logo.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['get']);
      expect(_logoImage, findsOneWidget);
    });

    testWidgets('confirming removes the logo and shows the fallback', (
      tester,
    ) async {
      final repository = _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png');
      await _pump(tester, repository);

      await tester.tap(_removeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove logo'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['get', 'remove']);
      expect(find.text('Shop logo removed.'), findsOneWidget);
      expect(_fallback, findsOneWidget);
      expect(_removeButton, findsNothing);
    });

    testWidgets('a removal failure is safe and reloads the logo', (
      tester,
    ) async {
      final repository = _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png')
        ..removeFailure = const ShopBrandingException(
          ShopBrandingErrorKind.removeFailed,
        );
      await _pump(tester, repository);

      await tester.tap(_removeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove logo'));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't remove the shop logo. Please try again."),
        findsOneWidget,
      );
      expect(repository.calls, ['get', 'remove', 'get']);
      expect(_logoImage, findsOneWidget);
      expect(_removeButton, findsOneWidget);
    });
  });

  for (final width in <double>[320, 1280]) {
    testWidgets('lays out without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeBrandingRepository(logoPath: 'shop-1/logo-1.png'),
        size: Size(width, 1600),
      );

      expect(tester.takeException(), isNull);
      expect(_changeButton, findsOneWidget);
    });
  }

  testWidgets('the profile card is not stretched on desktop', (tester) async {
    await _pump(
      tester,
      _FakeBrandingRepository(),
      size: const Size(1600, 1200),
    );

    final cardWidth = tester.getSize(find.text('Business Profile')).width;
    final column = tester.getSize(
      find
          .ancestor(
            of: find.text('Business Profile'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(column.width, lessThanOrEqualTo(640));
    expect(cardWidth, greaterThan(0));
  });
}
