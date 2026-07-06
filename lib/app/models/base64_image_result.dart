import 'local_image_file.dart';

/// Base64 图片处理结果模型，记录源文件、文本长度和导出路径。
///
/// 设计意图：图片转 Base64 与 Base64 还原图片共享一个轻量结果对象，界面
/// 只关心可展示的路径、大小和文本长度，避免直接持有大块二进制数据。
class Base64ImageResult {
  const Base64ImageResult({
    this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.base64Length,
    required this.mimeType,
  });

  final LocalImageFile? source;
  final String outputPath;
  final int outputSizeBytes;
  final int base64Length;
  final String mimeType;
}
