import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/shop/data/datasources/shop_branding_remote_datasource.dart';
import 'package:shopmate/features/shop/data/repositories/shop_branding_repository_impl.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_exception.dart';
import 'package:shopmate/features/shop/domain/entities/shop_logo_upload.dart';
import 'package:shopmate/features/shop/domain/entities/shop_profile_update.dart';

const _shopId = 'aaaaaaaa-0000-4000-8000-000000000000';
const _oldPath = '$_shopId/logo-1000.png';
const _now = 1760000000123;
const _newPath = '$_shopId/logo-$_now.png';
final _oldBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

ShopLogoUpload _pngUpload() {
  final bytes = Uint8List(32)
    ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return ShopLogoUpload(bytes: bytes, extension: 'png');
}

/// Loopback stand-in for the PostgREST and Storage APIs used by branding.
/// Keeps an in-memory shop row and bucket, records every call in order, and
/// can fail individual steps.
class _FakeBackend {
  late final HttpServer _server;

  final Map<String, Object?> shopRow = {
    'id': _shopId,
    'name': "Danny's Shop",
    'phone': '0240000001',
    'logo_path': null,
  };
  final Map<String, Uint8List> objects = {};
  final calls = <String>[];
  final readFilters = <String>[];
  final uploadUpsertHeaders = <String?>[];
  final uploadBodies = <String>[];

  bool failRead = false;
  bool failUpload = false;
  bool failSet = false;
  bool failClear = false;
  bool failDelete = false;
  bool failDownload = false;
  String? profileError;
  final profileParams = <Map<String, Object?>>[];

  String get url => 'http://${_server.address.host}:${_server.port}';

  static const _objectPrefix = '/storage/v1/object/shop-branding';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    // Multipart uploads carry raw image bytes, so decode leniently.
    final raw = await request.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final body = utf8.decode(raw, allowMalformed: true);
    final path = request.uri.path;

    if (path == '/rest/v1/shops' && request.method == 'GET') {
      calls.add('read');
      readFilters.add(request.uri.queryParameters['id'] ?? '');
      if (failRead) return _json(request, 500, {'message': 'read failed'});
      return _json(request, 200, shopRow);
    }

    if (path == '/rest/v1/rpc/set_shop_logo') {
      final logoPath = (jsonDecode(body) as Map)['p_path'] as String;
      calls.add('set:$logoPath');
      if (failSet) {
        return _json(request, 400, {
          'message': 'Only the shop owner can change the shop logo',
          'code': 'P0001',
        });
      }
      if (!objects.containsKey(logoPath)) {
        return _json(request, 400, {
          'message': 'Logo file was not found in shop branding storage',
          'code': 'P0001',
        });
      }
      shopRow['logo_path'] = logoPath;
      return _json(request, 200, logoPath);
    }

    if (path == '/rest/v1/rpc/update_shop_profile') {
      final params = Map<String, Object?>.from(jsonDecode(body) as Map);
      calls.add('profile');
      profileParams.add(params);
      final error = profileError;
      if (error != null) {
        return _json(request, 400, {'message': error, 'code': 'P0001'});
      }
      shopRow['name'] = params['p_name'];
      shopRow['phone'] = params['p_phone'];
      return _json(request, 200, null);
    }

    if (path == '/rest/v1/rpc/clear_shop_logo') {
      calls.add('clear');
      if (failClear) {
        return _json(request, 400, {
          'message': 'Only the shop owner can change the shop logo',
          'code': 'P0001',
        });
      }
      final previous = shopRow['logo_path'];
      shopRow['logo_path'] = null;
      return _json(request, 200, previous);
    }

    if (path == _objectPrefix && request.method == 'DELETE') {
      final prefixes = ((jsonDecode(body) as Map)['prefixes'] as List)
          .cast<String>();
      calls.add('delete:${prefixes.join(',')}');
      if (failDelete) {
        return _json(request, 500, {
          'statusCode': '500',
          'error': 'internal',
          'message': 'delete failed',
        });
      }
      for (final prefix in prefixes) {
        objects.remove(prefix);
      }
      return _json(request, 200, [
        for (final prefix in prefixes) {'name': prefix},
      ]);
    }

    if (path.startsWith('$_objectPrefix/')) {
      final objectPath = path.substring(_objectPrefix.length + 1);

      if (request.method == 'POST') {
        calls.add('upload:$objectPath');
        uploadUpsertHeaders.add(request.headers.value('x-upsert'));
        uploadBodies.add(body);
        if (failUpload) {
          return _json(request, 403, {
            'statusCode': '403',
            'error': 'Unauthorized',
            'message': 'new row violates row-level security policy',
          });
        }
        objects[objectPath] = Uint8List.fromList([1, 2, 3]);
        return _json(request, 200, {'Key': 'shop-branding/$objectPath'});
      }

      if (request.method == 'GET') {
        calls.add('download:$objectPath');
        final bytes = objects[objectPath];
        if (failDownload || bytes == null) {
          return _json(request, 400, {
            'statusCode': '404',
            'error': 'not_found',
            'message': 'Object not found',
          });
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('image', 'png')
          ..add(bytes);
        return request.response.close();
      }
    }

    return _json(request, 404, {'message': 'unexpected $path'});
  }

  Future<void> _json(HttpRequest request, int status, Object? json) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(json));
    return request.response.close();
  }
}

Matcher _throwsKind(ShopBrandingErrorKind kind) {
  return throwsA(
    isA<ShopBrandingException>().having((e) => e.kind, 'kind', kind),
  );
}

void main() {
  late _FakeBackend backend;
  late SupabaseClient client;
  late ShopBrandingRepositoryImpl repository;

  setUp(() async {
    backend = _FakeBackend();
    await backend.start();
    client = SupabaseClient(
      backend.url,
      'test-anon-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    repository = ShopBrandingRepositoryImpl(
      ShopBrandingRemoteDataSource(client, nowMillis: () => _now),
    );
  });

  tearDown(() async {
    await client.dispose();
    await backend.stop();
  });

  void givenExistingLogo() {
    backend.shopRow['logo_path'] = _oldPath;
    backend.objects[_oldPath] = _oldBytes;
  }

  group('read', () {
    test('reads the current shop row and downloads its logo', () async {
      givenExistingLogo();

      final result = await repository.getShopBranding(_shopId);

      expect(backend.readFilters.single, 'eq.$_shopId');
      expect(result.branding.name, "Danny's Shop");
      expect(result.branding.logoPath, _oldPath);
      expect(result.logoBytes, _oldBytes);
      expect(result.logoError, isNull);
      expect(backend.calls, ['read', 'download:$_oldPath']);
    });

    test('a shop without a logo downloads nothing', () async {
      final result = await repository.getShopBranding(_shopId);

      expect(result.branding.logoPath, isNull);
      expect(result.logoBytes, isNull);
      expect(backend.calls, ['read']);
    });

    test('a failed logo download keeps the branding', () async {
      givenExistingLogo();
      backend.failDownload = true;

      final result = await repository.getShopBranding(_shopId);

      expect(result.branding.name, "Danny's Shop");
      expect(result.logoBytes, isNull);
      expect(result.logoError?.kind, ShopBrandingErrorKind.logoUnavailable);
    });

    test('an unreadable shop row is reported as unavailable', () async {
      backend.failRead = true;

      expect(
        () => repository.getShopBranding(_shopId),
        _throwsKind(ShopBrandingErrorKind.unavailable),
      );
    });
  });

  group('upload', () {
    test('uploads, sets, deletes the old logo, then re-reads', () async {
      givenExistingLogo();

      final result = await repository.uploadLogo(_shopId, _pngUpload());

      expect(backend.calls, [
        'read',
        'upload:$_newPath',
        'set:$_newPath',
        'delete:$_oldPath',
        'read',
        'download:$_newPath',
      ]);
      expect(result.branding.logoPath, _newPath);
      expect(result.logoBytes, isNotNull);
      expect(result.cleanupError, isNull);
      expect(backend.objects.containsKey(_oldPath), isFalse);
    });

    test('uploads to the shop-branding bucket under the current shop id, '
        'without upsert', () async {
      await repository.uploadLogo(_shopId, _pngUpload());

      expect(_newPath, startsWith('$_shopId/logo-'));
      expect(_newPath, matches(RegExp(r'^[0-9a-f-]{36}/logo-[0-9]+\.png$')));
      expect(backend.calls, contains('upload:$_newPath'));
      expect(backend.uploadUpsertHeaders.single, 'false');
      expect(backend.uploadBodies.single, contains('image/png'));
    });

    test('with no previous logo nothing is deleted', () async {
      await repository.uploadLogo(_shopId, _pngUpload());

      expect(backend.calls.where((call) => call.startsWith('delete')), isEmpty);
    });

    test('if set_shop_logo fails the old logo is kept and the upload is '
        'cleaned up', () async {
      givenExistingLogo();
      backend.failSet = true;

      await expectLater(
        repository.uploadLogo(_shopId, _pngUpload()),
        _throwsKind(ShopBrandingErrorKind.permissionDenied),
      );

      expect(backend.calls, [
        'read',
        'upload:$_newPath',
        'set:$_newPath',
        'delete:$_newPath',
      ]);
      expect(backend.shopRow['logo_path'], _oldPath);
      expect(backend.objects.containsKey(_oldPath), isTrue);
      expect(backend.objects.containsKey(_newPath), isFalse);
    });

    test('a rejected storage upload never calls set_shop_logo', () async {
      givenExistingLogo();
      backend.failUpload = true;

      await expectLater(
        repository.uploadLogo(_shopId, _pngUpload()),
        _throwsKind(ShopBrandingErrorKind.permissionDenied),
      );

      expect(backend.calls, ['read', 'upload:$_newPath']);
      expect(backend.shopRow['logo_path'], _oldPath);
    });

    test(
      'if the old logo cannot be deleted the new logo still stands',
      () async {
        givenExistingLogo();
        backend.failDelete = true;

        final result = await repository.uploadLogo(_shopId, _pngUpload());

        expect(result.branding.logoPath, _newPath);
        expect(result.cleanupError?.kind, ShopBrandingErrorKind.cleanupFailed);
        expect(backend.shopRow['logo_path'], _newPath);
        expect(backend.calls.where((call) => call.startsWith('set:')), [
          'set:$_newPath',
        ]);
      },
    );
  });

  group('remove', () {
    test('clears the logo, deletes the returned path, then re-reads', () async {
      givenExistingLogo();

      final result = await repository.removeLogo(_shopId);

      expect(backend.calls, ['clear', 'delete:$_oldPath', 'read']);
      expect(result.branding.logoPath, isNull);
      expect(result.logoBytes, isNull);
      expect(result.cleanupError, isNull);
      expect(backend.objects, isEmpty);
    });

    test('with no logo nothing is deleted', () async {
      await repository.removeLogo(_shopId);

      expect(backend.calls, ['clear', 'read']);
    });

    test('a failed delete does not restore the cleared logo', () async {
      givenExistingLogo();
      backend.failDelete = true;

      final result = await repository.removeLogo(_shopId);

      expect(result.branding.logoPath, isNull);
      expect(result.cleanupError?.kind, ShopBrandingErrorKind.cleanupFailed);
      expect(backend.shopRow['logo_path'], isNull);
      expect(backend.calls.where((call) => call.startsWith('set:')), isEmpty);
    });

    test('a rejected clear deletes nothing', () async {
      givenExistingLogo();
      backend.failClear = true;

      await expectLater(
        repository.removeLogo(_shopId),
        _throwsKind(ShopBrandingErrorKind.permissionDenied),
      );

      expect(backend.calls, ['clear']);
      expect(backend.objects.containsKey(_oldPath), isTrue);
    });
  });

  group('business profile', () {
    test('sends the validated name and phone, then re-reads', () async {
      final result = await repository.updateProfile(
        _shopId,
        ShopProfileUpdate(name: '  ABC Mini Mart ', phone: ' 0241234567 '),
      );

      expect(backend.calls, ['profile', 'read']);
      expect(backend.profileParams.single, {
        'p_name': 'ABC Mini Mart',
        'p_phone': '0241234567',
      });
      expect(result.branding.name, 'ABC Mini Mart');
      expect(result.branding.phone, '0241234567');
    });

    test('a cleared phone is sent as null', () async {
      await repository.updateProfile(
        _shopId,
        ShopProfileUpdate(name: 'ABC Mini Mart', phone: ''),
      );

      expect(backend.profileParams.single['p_phone'], isNull);
    });

    test('an owner-only rejection is a permission failure', () async {
      backend.profileError =
          'Only the shop owner can change the business profile';

      await expectLater(
        repository.updateProfile(_shopId, ShopProfileUpdate(name: 'X Shop')),
        _throwsKind(ShopBrandingErrorKind.permissionDenied),
      );
      expect(backend.calls, ['profile']);
    });

    test('backend validation errors map to typed kinds', () async {
      backend.profileError = 'Business name must be 2 to 80 characters';
      await expectLater(
        repository.updateProfile(_shopId, ShopProfileUpdate(name: 'X Shop')),
        _throwsKind(ShopBrandingErrorKind.invalidName),
      );

      backend.profileError = 'Invalid phone number';
      await expectLater(
        repository.updateProfile(_shopId, ShopProfileUpdate(name: 'X Shop')),
        _throwsKind(ShopBrandingErrorKind.invalidPhone),
      );

      backend.profileError = 'something unexpected';
      await expectLater(
        repository.updateProfile(_shopId, ShopProfileUpdate(name: 'X Shop')),
        _throwsKind(ShopBrandingErrorKind.profileUpdateFailed),
      );
    });
  });
}
