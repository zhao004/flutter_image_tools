import 'local_image_file.dart';

/// 图片尺寸调整结果模型，记录输入文件、输出路径、目标尺寸和导出大小。
///
/// 设计意图：缩放结果独立于旋转、翻转和压缩结果，避免不同功能复用含义
/// 不一致的字段；输出宽高由 Dart 侧校验后传入，原生端返回文件导出信息。
class ResizedImageFile {
  const ResizedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final int width;
  final int height;

  factory ResizedImageFile.fromMap({
    required LocalImageFile source,
    required int width,
    required int height,
    required Map<Object?, Object?> map,
  }) {
    return ResizedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      width: map['width'] as int? ?? width,
      height: map['height'] as int? ?? height,
    );
  }
}
