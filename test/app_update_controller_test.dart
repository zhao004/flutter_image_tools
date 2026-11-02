import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/pages/update/update_controller.dart';
import 'package:flutter_image_tools/app/repositories/app_settings_repository.dart';
import 'package:flutter_image_tools/app/services/app_update_platform.dart';
import 'package:flutter_image_tools/app/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateController', () {
    late Directory temporaryDirectory;
    late AppDatabase database;
    late AppSettingsRepository repository;
    late _RecordingUpdatePlatform platform;

    setUp(() async {
      temporaryDirectory = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.cache'
        '${Platform.pathSeparator}app_update_controller_test',
      );
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
      await temporaryDirectory.create(recursive: true);
      database = AppDatabase(NativeDatabase.memory());
      repository = AppSettingsRepository(database: database);
      platform = _RecordingUpdatePlatform();
    });

    tearDown(() async {
      await database.close();
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('24 小时内自动检查直接跳过', () async {
      var requestCount = 0;
      await repository.setLastUpdateCheckAt(DateTime.utc(2026, 11, 2, 8));
      final controller = _buildTestController(
        MockClient((_) async {
          requestCount += 1;
          return _jsonResponse(
            _releaseJson('1.1.0', apkBytes: List<int>.filled(1, 0)),
          );
        }),
        platform,
        repository,
        temporaryDirectory,
        clock: () => DateTime.utc(2026, 11, 2, 12),
      );

      final release = await controller.checkAutomatically();

      expect(release, isNull);
      expect(requestCount, 0);
      controller.onClose();
    });

    test('同版本被暂缓后自动检查仍完成但不提示', () async {
      var requestCount = 0;
      await repository.setDismissedUpdateVersion('1.1.0');
      final controller = _buildTestController(
        MockClient((_) async {
          requestCount += 1;
          return _jsonResponse(
            _releaseJson('1.1.0', apkBytes: List<int>.filled(1, 0)),
          );
        }),
        platform,
        repository,
        temporaryDirectory,
      );

      final release = await controller.checkAutomatically();

      expect(release, isNull);
      expect(requestCount, 1);
      expect(controller.phase.value, AppUpdatePhase.updateAvailable);
      controller.onClose();
    });

    test('手动检查绕过节流并展示新版本', () async {
      var requestCount = 0;
      await repository.setLastUpdateCheckAt(DateTime.utc(2026, 11, 2, 8));
      final controller = _buildTestController(
        MockClient((_) async {
          requestCount += 1;
          return _jsonResponse(
            _releaseJson('1.1.0', apkBytes: List<int>.filled(1, 0)),
          );
        }),
        platform,
        repository,
        temporaryDirectory,
        clock: () => DateTime.utc(2026, 11, 2, 12),
      );

      await controller.checkForUpdates();

      expect(requestCount, 1);
      expect(controller.phase.value, AppUpdatePhase.updateAvailable);
      expect(controller.availableRelease.value?.versionText, '1.1.0');
      controller.onClose();
    });

    test('下载校验后引导授权并调起安装器', () async {
      final apkBytes = List<int>.generate(1024, (index) => index % 251);
      final digest = sha256.convert(apkBytes).toString();
      platform.installAllowed = false;
      final controller = _buildTestController(
        MockClient((request) async {
          if (request.url.path.endsWith('/SHA256SUMS.txt')) {
            return http.Response(
              '$digest  ./imagetoolkit-v1.1.0-arm64-v8a.apk\n',
              HttpStatus.ok,
            );
          }
          if (request.url.path.endsWith('.apk')) {
            return http.Response.bytes(apkBytes, HttpStatus.ok);
          }
          return _jsonResponse(_releaseJson('1.1.0', apkBytes: apkBytes));
        }),
        platform,
        repository,
        temporaryDirectory,
      );
      await controller.checkForUpdates();

      await controller.downloadAndInstall();

      expect(controller.phase.value, AppUpdatePhase.installPermissionRequired);
      expect(controller.hasDownloadedFile, isTrue);

      platform.installAllowed = true;
      await controller.refreshInstallPermission();
      expect(controller.phase.value, AppUpdatePhase.installReady);

      await controller.installDownloaded();
      expect(controller.phase.value, AppUpdatePhase.installerOpened);
      expect(platform.installedPaths, hasLength(1));
      expect(await File(platform.installedPaths.single).exists(), isTrue);
      controller.onClose();
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

AppUpdateController _buildTestController(
  http.Client client,
  AppUpdatePlatform platform,
  AppSettingsRepository repository,
  Directory temporaryDirectory, {
  DateTime Function()? clock,
}) {
  final service = AppUpdateService(
    platform: platform,
    client: client,
    versionLoader: () async => '1.0.0',
    temporaryDirectoryProvider: () async => temporaryDirectory,
  );
  return AppUpdateController(
    service: service,
    settingsRepository: repository,
    automaticChecksEnabled: true,
    clock: clock ?? () => DateTime.utc(2026, 11, 2, 12),
  );
}

Map<String, Object?> _releaseJson(
  String version, {
  required List<int> apkBytes,
}) {
  final tag = 'v$version';
  final assetName = 'imagetoolkit-$tag-arm64-v8a.apk';
  final releaseBase =
      'https://github.com/zhao004/flutter_image_tools/releases/download/$tag';
  return <String, Object?>{
    'tag_name': tag,
    'name': tag,
    'body': '更新说明',
    'published_at': '2026-11-02T14:20:54Z',
    'draft': false,
    'prerelease': false,
    'assets': [
      <String, Object?>{
        'name': assetName,
        'size': apkBytes.length,
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

class _RecordingUpdatePlatform implements AppUpdatePlatform {
  bool installAllowed = true;
  final List<String> installedPaths = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<bool> canInstallPackages() async => installAllowed;

  @override
  Future<String> getPreferredAbi() async => 'arm64-v8a';

  @override
  Future<void> installApk(String filePath) async {
    installedPaths.add(filePath);
  }

  @override
  Future<void> openInstallPermissionSettings() async {}
}
