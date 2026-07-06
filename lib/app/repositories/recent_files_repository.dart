import '../models/local_image_file.dart';
import '../database/database.dart';

/// 最近文件仓储，记录用户选择过的本地图片。
///
/// 边界处理：空路径不会写入，避免污染唯一索引；同一路径使用 upsert 更新
/// 最近使用时间，保证列表不会出现重复文件。
class RecentFilesRepository {
  RecentFilesRepository({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<List<RecentFile>> getRecentFiles({int limit = 10}) {
    return _database.getRecentFiles(limit: limit);
  }

  Future<void> recordImage(LocalImageFile image) async {
    if (image.path.trim().isEmpty) {
      return;
    }
    await _database.upsertRecentFile(
      RecentFilesCompanion.insert(
        filePath: image.path,
        fileName: image.name,
        mimeType: image.mimeType,
        sizeBytes: image.sizeBytes,
        lastUsedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
