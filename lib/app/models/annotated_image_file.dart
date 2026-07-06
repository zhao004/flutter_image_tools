import 'local_image_file.dart';

/// 图片标注结果模型，记录原图、标注模式和导出文件信息。
///
/// 设计意图：标注功能会在原图基础上生成新的图片副本，不覆盖源文件；
/// 模型只保存结果和关键参数，避免 UI 层直接依赖平台通道返回结构。
class AnnotatedImageFile {
  const AnnotatedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.mode,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final String mode;

  factory AnnotatedImageFile.fromMap({
    required LocalImageFile source,
    required String mode,
    required Map<Object?, Object?> map,
  }) {
    return AnnotatedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      mode: map['mode'] as String? ?? mode,
    );
  }
}
