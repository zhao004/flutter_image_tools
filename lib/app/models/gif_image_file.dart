import 'local_image_file.dart';

/// GIF 生成结果模型，记录输入帧、帧延迟、输出尺寸和导出路径。
///
/// 设计意图：GIF 由多张本地图片按固定延迟生成，模型保留源图片列表与
/// 编码参数，方便结果展示、历史记录追踪和后续扩展为变速帧。
class GifImageFile {
  const GifImageFile({
    required this.sources,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.frameCount,
    required this.delayMs,
    required this.width,
    required this.height,
  });

  final List<LocalImageFile> sources;
  final String outputPath;
  final int outputSizeBytes;
  final int frameCount;
  final int delayMs;
  final int width;
  final int height;

  bool get hasValidDimensions => width > 0 && height > 0;

  factory GifImageFile.fromMap({
    required List<LocalImageFile> sources,
    required int delayMs,
    required Map<Object?, Object?> map,
  }) {
    return GifImageFile(
      sources: List<LocalImageFile>.unmodifiable(sources),
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      frameCount: map['frameCount'] as int? ?? sources.length,
      delayMs: map['delayMs'] as int? ?? delayMs,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
    );
  }
}
