/// 缓存统计模型，保存缓存文件数量、目录大小和目录路径。
///
/// 设计意图：缓存管理页需要同时展示文件系统统计和数据库记录数量，集中建模
/// 可以避免页面直接拼装不同来源的数据。
class CacheSummary {
  const CacheSummary({
    required this.cacheDirectoryPath,
    required this.fileCount,
    required this.recordCount,
    required this.totalSizeBytes,
  });

  final String cacheDirectoryPath;
  final int fileCount;
  final int recordCount;
  final int totalSizeBytes;

  bool get hasCache => fileCount > 0 || recordCount > 0 || totalSizeBytes > 0;
}
