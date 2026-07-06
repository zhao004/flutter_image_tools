import 'local_image_file.dart';

/// GIF 压缩结果模型，记录源 GIF、输出路径、缩放比例和采样参数。
///
/// 设计意图：GIF 压缩通过降低尺寸和抽帧间隔减少文件体积，模型保留压缩
/// 前后大小，方便界面展示压缩效果并写入历史记录。
class CompressedGifFile {
  const CompressedGifFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.originalSizeBytes,
    required this.frameCount,
    required this.frameStepMs,
    required this.scalePercent,
    required this.width,
    required this.height,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final int originalSizeBytes;
  final int frameCount;
  final int frameStepMs;
  final int scalePercent;
  final int width;
  final int height;

  bool get hasValidOutput =>
      outputPath.trim().isNotEmpty &&
      outputSizeBytes > 0 &&
      frameCount > 0 &&
      width > 0 &&
      height > 0;

  int get savedSizeBytes =>
      (originalSizeBytes - outputSizeBytes).clamp(0, originalSizeBytes);

  double get savedRatio {
    if (originalSizeBytes <= 0) {
      return 0;
    }
    return savedSizeBytes / originalSizeBytes;
  }

  factory CompressedGifFile.fromMap({
    required LocalImageFile source,
    required int frameStepMs,
    required int scalePercent,
    required Map<Object?, Object?> map,
  }) {
    return CompressedGifFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      originalSizeBytes: map['originalSizeBytes'] as int? ?? source.sizeBytes,
      frameCount: map['frameCount'] as int? ?? 0,
      frameStepMs: map['frameStepMs'] as int? ?? frameStepMs,
      scalePercent: map['scalePercent'] as int? ?? scalePercent,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
    );
  }
}
