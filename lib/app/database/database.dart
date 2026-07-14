import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/app_settings.dart';
import 'tables/cache_records.dart';
import 'tables/operation_history.dart';
import 'tables/recent_files.dart';
import 'type/utc_date_time_converter.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [AppSettings, OperationHistory, RecentFiles, CacheRecords],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(appSettings);
        await migrator.createTable(recentFiles);
        await migrator.createTable(cacheRecords);
      }
      if (from < 3) {
        // 日志和收藏模板已并入更清晰的产品流程，升级时同步删除遗留表。
        await customStatement('DROP TABLE IF EXISTS operation_logs');
        await customStatement('DROP TABLE IF EXISTS favorite_templates');
      }
    },
  );

  Future<AppSetting?> getSetting(String key) {
    if (key.trim().isEmpty) {
      return Future.value(null);
    }
    return (select(
      appSettings,
    )..where((table) => table.settingKey.equals(key))).getSingleOrNull();
  }

  Future<int> upsertSetting(AppSettingsCompanion setting) async {
    if (!setting.settingKey.present) {
      return 0;
    }

    final settingKey = setting.settingKey.value.trim();
    if (settingKey.isEmpty) {
      return 0;
    }

    final normalizedSetting = setting.copyWith(settingKey: Value(settingKey));
    final existingSetting = await getSetting(settingKey);
    if (existingSetting == null) {
      return into(appSettings).insert(normalizedSetting);
    }

    // 设置项的唯一约束是 settingKey，更新时只覆盖可变字段，避免误写自增主键。
    return (update(
      appSettings,
    )..where((table) => table.settingKey.equals(settingKey))).write(
      AppSettingsCompanion(
        settingValue: setting.settingValue,
        valueType: setting.valueType,
        updatedAt: setting.updatedAt,
      ),
    );
  }

  Future<List<OperationHistoryData>> getRecentHistory({
    int limit = 20,
    int offset = 0,
    String keyword = '',
    String status = '',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (limit <= 0 || offset < 0) {
      return Future.value(const []);
    }
    final normalizedKeyword = keyword.trim();
    final normalizedStatus = status.trim();
    final query = select(operationHistory)
      ..orderBy([
        (table) => OrderingTerm.desc(table.createdAt),
        (table) => OrderingTerm.desc(table.id),
      ])
      ..limit(limit, offset: offset);

    if (normalizedKeyword.isNotEmpty) {
      query.where(
        (table) =>
            table.featureName.contains(normalizedKeyword) |
            table.inputPath.contains(normalizedKeyword) |
            table.parametersJson.contains(normalizedKeyword) |
            table.outputPath.contains(normalizedKeyword) |
            table.errorMessage.contains(normalizedKeyword),
      );
    }
    if (normalizedStatus.isNotEmpty) {
      query.where((table) => table.status.equals(normalizedStatus));
    }
    if (startDate != null) {
      query.where(
        (table) => table.createdAt.isBiggerOrEqualValue(startDate.toUtc()),
      );
    }
    if (endDate != null) {
      query.where(
        (table) => table.createdAt.isSmallerOrEqualValue(endDate.toUtc()),
      );
    }
    return query.get();
  }

  Future<int> createHistory(OperationHistoryCompanion history) =>
      into(operationHistory).insert(history);

  Future<int> deleteHistoryItem(int id) {
    if (id <= 0) {
      return Future.value(0);
    }
    return (delete(
      operationHistory,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<int> clearHistory() => delete(operationHistory).go();

  Future<int> upsertRecentFile(RecentFilesCompanion file) {
    return into(recentFiles).insertOnConflictUpdate(file);
  }

  Future<List<RecentFile>> getRecentFiles({int limit = 10}) {
    if (limit <= 0) {
      return Future.value(const []);
    }
    return (select(recentFiles)
          ..orderBy([(table) => OrderingTerm.desc(table.lastUsedAt)])
          ..limit(limit))
        .get();
  }

  Future<int> upsertCacheRecord(CacheRecordsCompanion record) {
    return into(cacheRecords).insertOnConflictUpdate(record);
  }

  Future<List<CacheRecord>> getCacheRecords() {
    return (select(
      cacheRecords,
    )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).get();
  }

  Future<int> deleteExpiredCacheRecords(DateTime now) {
    return (delete(
      cacheRecords,
    )..where((table) => table.expiresAt.isSmallerThanValue(now))).go();
  }

  Future<int> clearCacheRecords() => delete(cacheRecords).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_database.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
