import 'local_image_file.dart';

/// 图片裁剪结果模型，记录输入文件、导出路径、目标比例和导出大小。
///
/// 设计意图：裁剪结果需要同时展示目标比例和输出尺寸，方便用户确认
/// 本次居中裁剪是否符合预期；输出尺寸以原生端实际裁剪结果为准。
class CroppedImageFile {
  const CroppedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
    required this.aspectRatio,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final int width;
  final int height;
  final double aspectRatio;

  factory CroppedImageFile.fromMap({
    required LocalImageFile source,
    required double aspectRatio,
    required Map<Object?, Object?> map,
  }) {
    return CroppedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      aspectRatio: (map['aspectRatio'] as num?)?.toDouble() ?? aspectRatio,
    );
  }
}
