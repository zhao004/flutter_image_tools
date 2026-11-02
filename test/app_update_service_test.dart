import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_image_tools/app/exceptions/app_update_exception.dart';
import 'package:flutter_image_tools/app/services/app_update_platform.dart';
import 'package:flutter_image_tools/app/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AppUpdateService', () {
    late Directory temporaryDirectory;
    late _FakeUpdatePlatform platform;

    setUp(() async {
      temporaryDirectory = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.cache'
        '${Platform.pathSeparator}app_update_service_test',
      );
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
      await temporaryDirectory.create(recursive: true);
      platform = _FakeUpdatePlatform();
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('选择高于当前版本的稳定版和匹配 ABI 的 APK', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/releases/latest'));
        expect(
          request.headers.entries
              .firstWhere((entry) => entry.key.toLowerCase() == 'user-agent')
              .value,
          startsWith('ImageToolKit/'),
        );
        return _jsonResponse(_releaseJson(version: '1.1.0'));
      });
      final service = AppUpdateService(
        platform: platform,
        client: client,
        versionLoader: () async => '1.0.0',
      );

      final result = await service.checkForUpdate();

      expect(result.updateAvailable, isTrue);
      expect(result.latestVersion, '1.1.0');
      expect(result.preferredAbi, 'arm64-v8a');
      expect(
        result.release?.assetNamed('imagetoolkit-v1.1.0-arm64-v8a.apk'),
        isNotNull,
      );
      service.close();
    });

    test('当前版本已是最新时不解析 ABI', () async {
      final client = MockClient(
        (_) async => _jsonResponse(_releaseJson(version: '1.0.0')),
      );
      final service = AppUpdateService(
        platform: platform,
        client: client,
        versionLoader: () async => '1.0.0',
      );

      final result = await service.checkForUpdate();

      expect(result.updateAvailable, isFalse);
      expect(platform.preferredAbiCalls, 0);
      service.close();
    });

    test('拒绝预发布 Release', () async {
      final client = MockClient(
        (_) async => _jsonResponse(
          _releaseJson(version: '1.1.0-beta.1', prerelease: true),
        ),
      );
      final service = AppUpdateService(
        platform: platform,
        client: client,
        versionLoader: () async => '1.0.0',
      );

      await expectLater(
        service.checkForUpdate(),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.failureCode,
            'failureCode',
            AppUpdateFailureCode.invalidResponse,
          ),
        ),
      );
      service.close();
    });

    test('缺少当前 ABI 资产时返回明确错误', () async {
      final releaseJson = _releaseJson(version: '1.1.0');
      final assets = releaseJson['assets']! as List<Object?>;
      final apkAsset = assets.first! as Map<String, Object?>;
      apkAsset['name'] = 'imagetoolkit-v1.1.0-x86_64.apk';
      final client = MockClient((_) async => _jsonResponse(releaseJson));
      final service = AppUpdateService(
        platform: platform,
        client: client,
        versionLoader: () async => '1.0.0',
      );

      await expectLater(
        service.checkForUpdate(),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.failureCode,
            'failureCode',
            AppUpdateFailureCode.assetMissing,
          ),
        ),
      );
      service.close();
    });

    test('下载 APK 并通过 SHA256SUMS 校验', () async {
      final apkBytes = List<int>.generate(1024, (index) => index % 251);
      final digest = sha256.convert(apkBytes).toString();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return _jsonResponse(_releaseJson(version: '1.1.0'));
        }
        if (request.url.path.endsWith('/SHA256SUMS.txt')) {
          return http.Response(
            '$digest  ./imagetoolkit-v1.1.0-arm64-v8a.apk\n',
            HttpStatus.ok,
          );
        }
        return http.Response.bytes(apkBytes, HttpStatus.ok);
      });
      final service = AppUpdateService(
        platform: platform,
        client: client,
        versionLoader: () async => '1.0.0',
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );
      final result = await service.checkForUpdate();
      final release = result.release!;
      final asset = release.assetNamed('imagetoolkit-v1.1.0-arm64-v8a.apk')!;
      var progressReported = false;
      var verifyingReported = false;

      final download = await service.downloadAndVerify(
        release: release,
        asset: asset,
        onProgress: (_, _) => progressReported = true,
        onVerifying: () => verifyingReported = true,
      );

      expect(progressReported, isTrue);
      expect(verifyingReported, isTrue);
      expect(download.sha256, digest);
      expect(download.sizeBytes, apkBytes.length);
      expect(await File(download.filePath).readAsBytes(), apkBytes);
      service.close();
    });

    test('摘要不匹配时删除下载文件', () async {
      final apkBytes = List<int>.filled(1024, 7);
      final wrongDigest = sha256.convert(List<int>.filled(1024, 1)).toString();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return _jsonResponse(_releaseJson(version: '1.1.0'));
        }
        if (request.url.path.endsWith('/SHA256SUMS.txt')) {
          return http.Response(
            '$wrongDigest  ./imagetoolkit-v1.1.0-arm64-v8a.apk\n',
            HttpStatus.ok,
          );
        }
        return http.Response.bytes(apkBytes, HttpStatus.ok);
      });
      final service = AppUpdateService(
        platform: platform,
        client: client,
        versionLoader: () async => '1.0.0',
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );
      final result = await service.checkForUpdate();
      final release = result.release!;
      final asset = release.assetNamed('imagetoolkit-v1.1.0-arm64-v8a.apk')!;

      await expectLater(
        service.downloadAndVerify(release: release, asset: asset),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.failureCode,
            'failureCode',
            AppUpdateFailureCode.checksumMismatch,
          ),
        ),
      );
      final updateDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}updates',
      );
      expect(await updateDirectory.list().toList(), isEmpty);
      service.close();
    });
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    HttpStatus.ok,
    headers: const <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    },
  );
}

Map<String, Object?> _releaseJson({
  required String version,
  bool prerelease = false,
}) {
  final tag = 'v$version';
  final assetName = 'imagetoolkit-$tag-arm64-v8a.apk';
  final releaseBase =
      'https://github.com/zhao004/flutter_image_tools/releases/download/$tag';
  return <String, Object?>{
    'tag_name': tag,
    'name': tag,
    'body': '修复若干问题并提升稳定性。',
    'published_at': '2026-11-02T14:20:54Z',
    'draft': false,
    'prerelease': prerelease,
    'assets': [
      <String, Object?>{
        'name': assetName,
        'size': 1024,
        'browser_download_url': '$releaseBase/$assetName',
      },
      <String, Object?>{
        'name': 'SHA256SUMS.txt',
        'size': 128,
        'browser_download_url': '$releaseBase/SHA256SUMS.txt',
      },
    ],
  };
}

class _FakeUpdatePlatform implements AppUpdatePlatform {
  int preferredAbiCalls = 0;
  bool installAllowed = true;

  @override
  bool get isSupported => true;

  @override
  Future<bool> canInstallPackages() async => installAllowed;

  @override
  Future<String> getPreferredAbi() async {
    preferredAbiCalls += 1;
    return 'arm64-v8a';
  }

  @override
  Future<void> installApk(String filePath) async {}

  @override
  Future<void> openInstallPermissionSettings() async {}
}
