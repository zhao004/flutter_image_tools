import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/app_settings.dart';
import 'tables/cache_records.dart';
import 'tables/favorite_templates.dart';
import 'tables/operation_history.dart';
import 'tables/operation_logs.dart';
import 'tables/recent_files.dart';
import 'type/utc_date_time_converter.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    AppSettings,
    OperationHistory,
    OperationLogs,
    FavoriteTemplates,
    RecentFiles,
    CacheRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(appSettings);
        await migrator.createTable(favoriteTemplates);
        await migrator.createTable(recentFiles);
        await migrator.createTable(cacheRecords);
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

  Future<int> upsertSetting(AppSettingsCompanion setting) {
    return into(appSettings).insertOnConflictUpdate(setting);
  }

  Future<List<OperationHistoryData>> getRecentHistory({
    int limit = 50,
    String keyword = '',
    String status = '',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (limit <= 0) {
      return Future.value(const []);
    }
    final normalizedKeyword = keyword.trim();
    final normalizedStatus = status.trim();
    final query = select(operationHistory)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
      ..limit(limit);

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

  Future<int> createLog(OperationLogsCompanion log) =>
      into(operationLogs).insert(log);

  Future<List<OperationLog>> getRecentLogs({
    int limit = 100,
    String keyword = '',
    String status = '',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (limit <= 0) {
      return Future.value(const []);
    }
    final normalizedKeyword = keyword.trim();
    final normalizedStatus = status.trim();
    final query = select(operationLogs)
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)])
      ..limit(limit);

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
        (table) => table.startedAt.isBiggerOrEqualValue(startDate.toUtc()),
      );
    }
    if (endDate != null) {
      query.where(
        (table) => table.startedAt.isSmallerOrEqualValue(endDate.toUtc()),
      );
    }
    return query.get();
  }

  Future<int> clearLogs() => delete(operationLogs).go();

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

  Future<int> createFavoriteTemplate(FavoriteTemplatesCompanion template) {
    return into(favoriteTemplates).insert(template);
  }

  Future<List<FavoriteTemplate>> getFavoriteTemplates({
    int limit = 20,
    String keyword = '',
  }) {
    if (limit <= 0) {
      return Future.value(const []);
    }
    final normalizedKeyword = keyword.trim();
    final query = select(favoriteTemplates)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])
      ..limit(limit);
    if (normalizedKeyword.isNotEmpty) {
      query.where(
        (table) =>
            table.featureName.contains(normalizedKeyword) |
            table.templateName.contains(normalizedKeyword) |
            table.parametersJson.contains(normalizedKeyword),
      );
    }
    return query.get();
  }

  Future<int> deleteFavoriteTemplate(int id) {
    if (id <= 0) {
      return Future.value(0);
    }
    return (delete(
      favoriteTemplates,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<int> clearFavoriteTemplates() => delete(favoriteTemplates).go();

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
