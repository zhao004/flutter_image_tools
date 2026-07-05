/// PDF 指定页面导出图片结果，记录源 PDF、页码和输出图片信息。
///
/// 设计意图：PDF 转图片与图片转 PDF 使用独立模型，避免页面导出字段污染
/// 生成 PDF 的结果对象；页码统一使用用户可见的 1-based 编号，便于界面展示。
class PdfPageImageFile {
  const PdfPageImageFile({
    required this.sourcePath,
    required this.sourceName,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.pageNumber,
    required this.pageCount,
    required this.width,
    required this.height,
  });

  final String sourcePath;
  final String sourceName;
  final String outputPath;
  final int outputSizeBytes;
  final int pageNumber;
  final int pageCount;
  final int width;
  final int height;

  bool get hasValidDimensions => width > 0 && height > 0;

  factory PdfPageImageFile.fromMap({
    required String sourcePath,
    required String sourceName,
    required int requestedPageNumber,
    required Map<Object?, Object?> map,
  }) {
    return PdfPageImageFile(
      sourcePath: sourcePath,
      sourceName: sourceName,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      pageNumber: map['pageNumber'] as int? ?? requestedPageNumber,
      pageCount: map['pageCount'] as int? ?? 0,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
    );
  }
}
