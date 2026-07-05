import 'local_image_file.dart';

/// GIF 拆帧导出结果模型，记录源 GIF、导出目录、帧路径和采样参数。
///
/// 设计意图：Android 侧按固定时间间隔将 GIF 动画帧导出为 PNG，Dart 侧
/// 冻结路径列表并校验数量，避免结果展示时被外部修改。
class GifFramesExport {
  const GifFramesExport({
    required this.source,
    required this.outputDirectory,
    required this.outputPaths,
    required this.totalOutputSizeBytes,
    required this.frameCount,
    required this.durationMs,
    required this.frameStepMs,
    required this.width,
    required this.height,
  });

  final LocalImageFile source;
  final String outputDirectory;
  final List<String> outputPaths;
  final int totalOutputSizeBytes;
  final int frameCount;
  final int durationMs;
  final int frameStepMs;
  final int width;
  final int height;

  bool get hasValidDimensions => width > 0 && height > 0;

  bool get isComplete =>
      outputDirectory.trim().isNotEmpty &&
      outputPaths.isNotEmpty &&
      frameCount == outputPaths.length &&
      hasValidDimensions;

  factory GifFramesExport.fromMap({
    required LocalImageFile source,
    required int frameStepMs,
    required Map<Object?, Object?> map,
  }) {
    final rawPaths = map['outputPaths'];
    final paths = rawPaths is List<Object?>
        ? rawPaths.whereType<String>().where((path) => path.isNotEmpty).toList()
        : const <String>[];
    return GifFramesExport(
      source: source,
      outputDirectory: map['outputDirectory'] as String? ?? '',
      outputPaths: List<String>.unmodifiable(paths),
      totalOutputSizeBytes: map['totalOutputSizeBytes'] as int? ?? 0,
      frameCount: map['frameCount'] as int? ?? paths.length,
      durationMs: map['durationMs'] as int? ?? 0,
      frameStepMs: map['frameStepMs'] as int? ?? frameStepMs,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
    );
  }
}
