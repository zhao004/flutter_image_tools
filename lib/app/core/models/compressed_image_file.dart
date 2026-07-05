import 'local_image_file.dart';

/// 图片压缩结果模型，记录输入文件、输出路径和压缩后大小。
///
/// 设计意图：结果对象保持不可变，便于写入历史记录和在界面层安全展示。
class CompressedImageFile {
  const CompressedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;

  double get savedRatio {
    if (source.sizeBytes <= 0) {
      return 0;
    }
    final savedBytes = source.sizeBytes - outputSizeBytes;
    return savedBytes <= 0 ? 0 : savedBytes / source.sizeBytes;
  }

  factory CompressedImageFile.fromMap({
    required LocalImageFile source,
    required Map<Object?, Object?> map,
  }) {
    return CompressedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
    );
  }
}
