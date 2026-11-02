import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/models/app_update_release.dart';
import 'package:flutter_image_tools/app/pages/settings/settings_controller.dart';
import 'package:flutter_image_tools/app/pages/settings/settings_view.dart';
import 'package:flutter_image_tools/app/pages/update/update_controller.dart';
import 'package:flutter_image_tools/app/pages/update/update_view.dart';
import 'package:flutter_image_tools/app/repositories/app_settings_repository.dart';
import 'package:flutter_image_tools/app/services/app_update_platform.dart';
import 'package:flutter_image_tools/app/services/app_update_service.dart';
import 'package:flutter_image_tools/app/theme/app_theme.dart';
import 'package:flutter_image_tools/app/theme/app_translations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late AppSettingsRepository repository;
  late AppUpdateController updateController;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = AppSettingsRepository(database: database);
    final service = AppUpdateService(
      platform: _FakeUpdatePlatform(),
      client: MockClient((_) async => throw StateError('界面测试不应访问网络')),
      versionLoader: () async => '1.0.0',
    );
    updateController = AppUpdateController(
      service: service,
      settingsRepository: repository,
      automaticChecksEnabled: false,
    );
    Get.put<AppUpdateController>(updateController);
    await updateController.initialize();
    updateController.phase.value = AppUpdatePhase.updateAvailable;
    updateController.currentVersion.value = '1.0.0';
    updateController.latestVersion.value = '1.1.0';
    updateController.preferredAbi.value = 'arm64-v8a';
    updateController.availableRelease.value = _release();
  });

  tearDown(() async {
    Get.reset();
    await database.close();
  });

  testWidgets('设置页显示软件更新入口', (tester) async {
    Get.put<SettingsController>(
      SettingsController(
        settingsRepository: _StaticSettingsRepository(database: database),
      ),
    );
    await tester.pumpWidget(_testApp(home: const SettingsView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('软件更新'), findsOneWidget);
    expect(find.text('发现新版本 1.1.0'), findsOneWidget);
  });

  testWidgets('更新页展示版本、说明和下载操作', (tester) async {
    await tester.pumpWidget(_testApp(home: const UpdateView()));
    await tester.pumpAndSettle();

    expect(find.text('软件更新'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('1.1.0'), findsOneWidget);
    expect(find.text('修复问题并提升稳定性。'), findsOneWidget);
    expect(find.text('下载并安装'), findsOneWidget);
  });

  testWidgets('更新页在窄屏下无布局溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(home: const UpdateView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(UpdateView), findsOneWidget);
  });
}

Widget _testApp({required Widget home}) {
  return GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('zh', 'CN'),
    fallbackLocale: const Locale('zh', 'CN'),
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: home,
  );
}

AppUpdateRelease _release() {
  return AppUpdateRelease(
    tagName: 'v1.1.0',
    displayName: 'v1.1.0',
    releaseNotes: '修复问题并提升稳定性。',
    publishedAt: DateTime.utc(2026, 11, 2),
    isPrerelease: false,
    isDraft: false,
    assets: [
      AppUpdateAsset(
        name: 'imagetoolkit-v1.1.0-arm64-v8a.apk',
        downloadUrl: Uri.parse(
          'https://github.com/zhao004/flutter_image_tools/releases/download/v1.1.0/imagetoolkit-v1.1.0-arm64-v8a.apk',
        ),
        sizeBytes: 1024,
      ),
      AppUpdateAsset(
        name: 'SHA256SUMS.txt',
        downloadUrl: Uri.parse(
          'https://github.com/zhao004/flutter_image_tools/releases/download/v1.1.0/SHA256SUMS.txt',
        ),
        sizeBytes: 128,
      ),
    ],
  );
}

class _FakeUpdatePlatform implements AppUpdatePlatform {
  @override
  bool get isSupported => true;

  @override
  Future<bool> canInstallPackages() async => true;

  @override
  Future<String> getPreferredAbi() async => 'arm64-v8a';

  @override
  Future<void> installApk(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw StateError('缺少安装包');
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {}
}

class _StaticSettingsRepository extends AppSettingsRepository {
  _StaticSettingsRepository({required super.database});

  @override
  Future<String> getDefaultExportFormat() async => 'jpg';

  @override
  Future<String> getDefaultSaveRule() async => 'timestamp';

  @override
  Future<String> getThemeMode() async => 'system';

  @override
  Future<String> getLanguage() async => 'zh_cn';

  @override
  Future<String?> getDefaultExportDirectory() async => null;
}
