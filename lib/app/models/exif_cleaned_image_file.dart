import 'local_image_file.dart';

/// EXIF 清理结果模型，记录原图和重新编码后的无元数据导出文件。
///
/// 设计意图：删除 EXIF 不覆盖原文件，而是生成新的 JPEG 副本；这样能避免
/// 原始照片不可逆损坏，也便于历史记录追踪输出位置和体积变化。
class ExifCleanedImageFile {
  const ExifCleanedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;

  factory ExifCleanedImageFile.fromMap({
    required LocalImageFile source,
    required Map<Object?, Object?> map,
  }) {
    return ExifCleanedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
    );
  }
}
