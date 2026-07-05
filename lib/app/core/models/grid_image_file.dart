import 'local_image_file.dart';

/// 九宫格切图结果模型，记录源图、网格参数、输出目录和全部切片路径。
///
/// 设计意图：切图会产生多个文件，模型保留目录和路径列表，便于结果页展示、
/// 历史记录追踪和后续批量分享；解析时过滤空路径，避免原生异常返回污染结果。
class GridImageFile {
  const GridImageFile({
    required this.source,
    required this.outputDirectory,
    required this.outputPaths,
    required this.outputSizeBytes,
    required this.gridSize,
    required this.pieceCount,
  });

  final LocalImageFile source;
  final String outputDirectory;
  final List<String> outputPaths;
  final int outputSizeBytes;
  final int gridSize;
  final int pieceCount;

  factory GridImageFile.fromMap({
    required LocalImageFile source,
    required int gridSize,
    required Map<Object?, Object?> map,
  }) {
    final paths = (map['outputPaths'] as List<Object?>? ?? const [])
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList(growable: false);
    return GridImageFile(
      source: source,
      outputDirectory: map['outputDirectory'] as String? ?? '',
      outputPaths: paths,
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      gridSize: map['gridSize'] as int? ?? gridSize,
      pieceCount: map['pieceCount'] as int? ?? paths.length,
    );
  }
}
