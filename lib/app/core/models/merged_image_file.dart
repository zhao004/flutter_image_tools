import 'local_image_file.dart';

/// 图片拼接结果模型，记录输入图片、拼接模式、输出尺寸和导出路径。
///
/// 设计意图：拼接结果需要展示输入数量、布局模式和最终画布尺寸，帮助用户
/// 判断横向、纵向或网格拼接是否符合预期。
class MergedImageFile {
  const MergedImageFile({
    required this.sources,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
    required this.mode,
    required this.backgroundColor,
    required this.borderWidth,
    required this.borderColor,
    required this.cornerRadius,
    required this.scaleMode,
  });

  final List<LocalImageFile> sources;
  final String outputPath;
  final int outputSizeBytes;
  final int width;
  final int height;
  final String mode;
  final String backgroundColor;
  final int borderWidth;
  final String borderColor;
  final int cornerRadius;
  final String scaleMode;

  factory MergedImageFile.fromMap({
    required List<LocalImageFile> sources,
    required String mode,
    required String backgroundColor,
    required int borderWidth,
    required String borderColor,
    required int cornerRadius,
    required String scaleMode,
    required Map<Object?, Object?> map,
  }) {
    return MergedImageFile(
      sources: List.unmodifiable(sources),
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      mode: map['mode'] as String? ?? mode,
      backgroundColor: map['backgroundColor'] as String? ?? backgroundColor,
      borderWidth: map['borderWidth'] as int? ?? borderWidth,
      borderColor: map['borderColor'] as String? ?? borderColor,
      cornerRadius: map['cornerRadius'] as int? ?? cornerRadius,
      scaleMode: map['scaleMode'] as String? ?? scaleMode,
    );
  }
}
