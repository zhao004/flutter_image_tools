import 'local_image_file.dart';

/// 图片转 PDF 结果模型，记录输入图片、页面规格和导出文件信息。
///
/// 设计意图：PDF 一次可能包含多张图片，模型保留所有源文件和页面参数，
/// 方便结果页展示、历史记录追踪和后续复用导出配置。
class PdfImageFile {
  const PdfImageFile({
    required this.sources,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.pageSize,
    required this.orientation,
    required this.pageCount,
  });

  final List<LocalImageFile> sources;
  final String outputPath;
  final int outputSizeBytes;
  final String pageSize;
  final String orientation;
  final int pageCount;

  factory PdfImageFile.fromMap({
    required List<LocalImageFile> sources,
    required String pageSize,
    required String orientation,
    required Map<Object?, Object?> map,
  }) {
    return PdfImageFile(
      sources: List<LocalImageFile>.unmodifiable(sources),
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      pageSize: map['pageSize'] as String? ?? pageSize,
      orientation: map['orientation'] as String? ?? orientation,
      pageCount: map['pageCount'] as int? ?? sources.length,
    );
  }
}
