import 'local_image_file.dart';

/// 条码/二维码识别结果模型，记录源图片、识别文本、格式和原始字节数量。
///
/// 设计意图：识别能力由 Android 本地解码器完成，Dart 侧只保留稳定展示和
/// 历史记录所需字段；格式为空时使用 unknown，避免平台差异影响界面。
class BarcodeScanResult {
  const BarcodeScanResult({
    required this.source,
    required this.text,
    required this.format,
    required this.rawBytesLength,
  });

  final LocalImageFile source;
  final String text;
  final String format;
  final int rawBytesLength;

  bool get hasText => text.trim().isNotEmpty;

  factory BarcodeScanResult.fromMap({
    required LocalImageFile source,
    required Map<Object?, Object?> map,
  }) {
    return BarcodeScanResult(
      source: source,
      text: map['text'] as String? ?? '',
      format: map['format'] as String? ?? 'unknown',
      rawBytesLength: map['rawBytesLength'] as int? ?? 0,
    );
  }
}
