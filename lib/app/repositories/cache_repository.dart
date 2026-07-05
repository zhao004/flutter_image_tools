import 'package:drift/drift.dart';

import '../database/database.dart';

/// 缓存记录仓储，集中管理导出缓存和缩略图缓存元数据。
///
/// 第一阶段只落地表和基础写入/清理能力；真正删除磁盘文件会在缓存管理页接入，
/// 避免仓储层直接承担文件系统副作用。
class CacheRepository {
  CacheRepository({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<void> recordCache({
    required String cacheKey,
    required String filePath,
    required int sizeBytes,
    DateTime? expiresAt,
  }) async {
    if (cacheKey.trim().isEmpty || filePath.trim().isEmpty || sizeBytes < 0) {
      throw ArgumentError('缓存键、路径和大小必须有效');
    }
    await _database.upsertCacheRecord(
      CacheRecordsCompanion.insert(
        cacheKey: cacheKey,
        filePath: filePath,
        sizeBytes: sizeBytes,
        createdAt: DateTime.now().toUtc(),
        expiresAt: Value(expiresAt?.toUtc()),
      ),
    );
  }

  Future<int> clearExpiredRecords() {
    return _database.deleteExpiredCacheRecords(DateTime.now().toUtc());
  }

  Future<List<CacheRecord>> getRecords() {
    return _database.getCacheRecords();
  }

  Future<int> clearRecords() {
    return _database.clearCacheRecords();
  }
}
