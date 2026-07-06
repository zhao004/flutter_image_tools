import 'local_image_file.dart';

/// 图片 EXIF 信息模型，保存可展示的元数据键值。
///
/// 边界处理：部分图片没有 EXIF 或只包含少数字段，模型统一返回有序 Map，
/// 页面只负责渲染，避免在 UI 层判断平台字段差异。
class ExifInfo {
  const ExifInfo({required this.source, required this.attributes});

  final LocalImageFile source;
  final Map<String, String> attributes;

  bool get hasExif => attributes.isNotEmpty;

  factory ExifInfo.fromMap({
    required LocalImageFile source,
    required Map<Object?, Object?> map,
  }) {
    final rawAttributes = map['attributes'];
    final attributes = <String, String>{};
    if (rawAttributes is Map<Object?, Object?>) {
      for (final entry in rawAttributes.entries) {
        final key = entry.key?.toString().trim() ?? '';
        final value = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty && value.isNotEmpty) {
          attributes[key] = value;
        }
      }
    }
    return ExifInfo(source: source, attributes: attributes);
  }
}
