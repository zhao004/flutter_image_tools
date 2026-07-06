import 'local_image_file.dart';

/// 图片格式转换结果模型，记录输入文件、目标格式、输出路径和导出大小。
///
/// 设计意图：格式转换需要保留目标格式语义，避免只展示导出路径时用户无法
/// 判断输出类型；原生端负责实际编码，Dart 侧负责校验和结果展示。
class ConvertedImageFile {
  const ConvertedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.format,
    required this.mimeType,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final String format;
  final String mimeType;

  factory ConvertedImageFile.fromMap({
    required LocalImageFile source,
    required String format,
    required Map<Object?, Object?> map,
  }) {
    return ConvertedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      format: map['format'] as String? ?? format,
      mimeType: map['mimeType'] as String? ?? 'image/$format',
    );
  }
}
