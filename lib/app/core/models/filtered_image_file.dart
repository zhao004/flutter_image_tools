import 'local_image_file.dart';

/// 图片滤镜结果模型，记录输入文件、滤镜类型、输出路径和导出大小。
///
/// 设计意图：滤镜结果保留业务语义，便于结果页展示和历史记录追踪，
/// 避免用户只看到导出路径时无法判断应用了哪种滤镜。
class FilteredImageFile {
  const FilteredImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.filter,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final String filter;

  factory FilteredImageFile.fromMap({
    required LocalImageFile source,
    required String filter,
    required Map<Object?, Object?> map,
  }) {
    return FilteredImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      filter: map['filter'] as String? ?? filter,
    );
  }
}
