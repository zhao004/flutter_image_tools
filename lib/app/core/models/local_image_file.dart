/// 本地图片文件模型，承载原始路径、名称、大小和 MIME 信息。
///
/// 边界处理：Android 选择器可能无法返回真实文件名或大小，字段允许使用
/// 安全默认值，后续导出和历史记录仍可稳定运行。
class LocalImageFile {
  const LocalImageFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final String mimeType;
  final int width;
  final int height;

  bool get hasValidDimensions => width > 0 && height > 0;

  factory LocalImageFile.fromMap(Map<Object?, Object?> map) {
    final path = map['path'] as String? ?? '';
    final name = map['name'] as String? ?? '未命名图片';
    final sizeBytes = map['sizeBytes'] as int? ?? 0;
    final mimeType = map['mimeType'] as String? ?? 'image/*';
    final width = map['width'] as int? ?? 0;
    final height = map['height'] as int? ?? 0;
    return LocalImageFile(
      path: path,
      name: name,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      width: width,
      height: height,
    );
  }
}
