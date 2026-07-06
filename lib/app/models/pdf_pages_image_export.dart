/// PDF 全部页面导出图片结果，记录输出目录、全部图片路径和总大小。
///
/// 设计意图：全部页面导出一次会生成多个 PNG 文件，独立模型能清晰表达
/// 批量结果；路径列表冻结，避免结果展示过程中被外部修改。
class PdfPagesImageExport {
  const PdfPagesImageExport({
    required this.sourcePath,
    required this.sourceName,
    required this.outputDirectory,
    required this.outputPaths,
    required this.totalOutputSizeBytes,
    required this.pageCount,
  });

  final String sourcePath;
  final String sourceName;
  final String outputDirectory;
  final List<String> outputPaths;
  final int totalOutputSizeBytes;
  final int pageCount;

  bool get isComplete => pageCount > 0 && outputPaths.length == pageCount;

  factory PdfPagesImageExport.fromMap({
    required String sourcePath,
    required String sourceName,
    required Map<Object?, Object?> map,
  }) {
    final paths = (map['outputPaths'] as List<Object?>? ?? const <Object?>[])
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList(growable: false);
    return PdfPagesImageExport(
      sourcePath: sourcePath,
      sourceName: sourceName,
      outputDirectory: map['outputDirectory'] as String? ?? '',
      outputPaths: List<String>.unmodifiable(paths),
      totalOutputSizeBytes: map['totalOutputSizeBytes'] as int? ?? 0,
      pageCount: map['pageCount'] as int? ?? paths.length,
    );
  }
}
