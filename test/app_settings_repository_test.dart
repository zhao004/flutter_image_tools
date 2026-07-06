import 'package:drift/native.dart';
import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/repositories/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettingsRepository', () {
    late AppDatabase database;
    late AppSettingsRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = AppSettingsRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('最近工具路由去重并限制数量', () async {
      // 最近工具用于首页快捷入口，保存时需要去重和截断，避免历史数据撑大设置表。
      await repository.setRecentToolRoutes(const [
        '/compress',
        '/resize',
        '/compress',
        '/pdf',
        '/gif',
        '/base64',
        '/settings',
        '/history',
        '/batch',
        '/qrcode',
      ]);

      final routes = await repository.getRecentToolRoutes();

      expect(routes, hasLength(AppSettingsRepository.maxRecentToolRoutes));
      expect(routes.first, '/compress');
      expect(routes.where((route) => route == '/compress'), hasLength(1));
      expect(routes, isNot(contains('/qrcode')));
    });

    test('最近工具路由遇到损坏 JSON 时回退为空列表', () async {
      await database.upsertSetting(
        AppSettingsCompanion.insert(
          settingKey: AppSettingsRepository.recentToolRoutesKey,
          settingValue: '{bad json',
          valueType: 'json',
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      expect(await repository.getRecentToolRoutes(), isEmpty);
    });

    test('收藏工具路由去重并忽略空值', () async {
      await repository.setFavoriteToolRoutes(const [
        '/compress',
        '',
        '  /settings  ',
        '/compress',
      ]);

      expect(await repository.getFavoriteToolRoutes(), [
        '/compress',
        '/settings',
      ]);
    });

    test('基础设置重复保存时覆盖旧值', () async {
      // 设置页会频繁重复保存同一个 key，仓储层必须按 settingKey 覆盖，
      // 不能因为自增主键或唯一键冲突让界面误报“保存失败”。
      await repository.setDefaultExportFormat('jpg');
      await repository.setDefaultExportFormat('png');
      await repository.setDefaultSaveRule('timestamp');
      await repository.setDefaultSaveRule('source_name');
      await repository.setThemeMode('system');
      await repository.setThemeMode('dark');
      await repository.setLanguage('system');
      await repository.setLanguage('en');

      expect(await repository.getDefaultExportFormat(), 'png');
      expect(await repository.getDefaultSaveRule(), 'source_name');
      expect(await repository.getThemeMode(), 'dark');
      expect(await repository.getLanguage(), 'en');
    });
  });
}
