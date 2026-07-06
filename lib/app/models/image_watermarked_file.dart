import 'local_image_file.dart';

/// 图片水印结果模型，记录底图、水印图、输出路径和导出参数。
///
/// 设计意图：图片水印由两张图片合成，模型保留两端来源和关键参数，便于
/// 结果页展示、历史追踪和后续复用最近配置。
class ImageWatermarkedFile {
  const ImageWatermarkedFile({
    required this.source,
    required this.watermark,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.position,
    required this.opacity,
    required this.scalePercent,
    required this.rotationDegrees,
  });

  final LocalImageFile source;
  final LocalImageFile watermark;
  final String outputPath;
  final int outputSizeBytes;
  final String position;
  final int opacity;
  final int scalePercent;
  final int rotationDegrees;

  factory ImageWatermarkedFile.fromMap({
    required LocalImageFile source,
    required LocalImageFile watermark,
    required String position,
    required int opacity,
    required int scalePercent,
    required int rotationDegrees,
    required Map<Object?, Object?> map,
  }) {
    return ImageWatermarkedFile(
      source: source,
      watermark: watermark,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      position: map['position'] as String? ?? position,
      opacity: map['opacity'] as int? ?? opacity,
      scalePercent: map['scalePercent'] as int? ?? scalePercent,
      rotationDegrees: map['rotationDegrees'] as int? ?? rotationDegrees,
    );
  }
}
