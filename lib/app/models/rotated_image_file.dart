import 'local_image_file.dart';

/// 图片旋转结果模型，记录输入文件、输出路径、输出大小和旋转角度。
///
/// 设计意图：旋转结果与压缩结果分离，避免不同功能共享语义不清的字段；
/// 输出大小允许为 0，用于兼容部分系统暂时无法立即统计文件大小的边界。
class RotatedImageFile {
  const RotatedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.degrees,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final int degrees;

  factory RotatedImageFile.fromMap({
    required LocalImageFile source,
    required int degrees,
    required Map<Object?, Object?> map,
  }) {
    return RotatedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      degrees: degrees,
    );
  }
}
