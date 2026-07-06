/// 本地 PDF 文件模型，承载文件路径、名称和大小。
///
/// 边界处理：Android 文件选择器可能无法返回真实文件名或大小，模型保留
/// 安全默认值；后续页码校验由原生 PdfRenderer 基于实际文件页数完成。
class PdfDocumentFile {
  const PdfDocumentFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final String mimeType;

  factory PdfDocumentFile.fromMap(Map<Object?, Object?> map) {
    return PdfDocumentFile(
      path: map['path'] as String? ?? '',
      name: map['name'] as String? ?? '未命名 PDF',
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      mimeType: map['mimeType'] as String? ?? 'application/pdf',
    );
  }
}
