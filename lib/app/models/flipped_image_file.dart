import 'local_image_file.dart';

/// 图片翻转结果模型，记录输入文件、输出路径、输出大小和翻转方向。
///
/// 设计意图：翻转结果保持独立模型，便于历史记录、结果页和后续批量翻转
/// 明确表达业务语义，避免复用旋转字段造成方向含义不清。
class FlippedImageFile {
  const FlippedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.direction,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final String direction;

  factory FlippedImageFile.fromMap({
    required LocalImageFile source,
    required String direction,
    required Map<Object?, Object?> map,
  }) {
    return FlippedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      direction: direction,
    );
  }
}
