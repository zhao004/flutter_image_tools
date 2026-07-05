/// 条形码生成结果模型，记录输入文本、编码类型和导出图片信息。
///
/// 设计意图：条形码和二维码共用导出流程，但条形码需要保留编码制式、
/// 像素宽高和内容长度，方便界面明确展示当前生成的是一维码。
class BarcodeImageFile {
  const BarcodeImageFile({
    required this.content,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.format,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final String content;
  final String outputPath;
  final int outputSizeBytes;
  final String format;
  final int pixelWidth;
  final int pixelHeight;

  bool get hasValidOutput =>
      content.trim().isNotEmpty &&
      outputPath.trim().isNotEmpty &&
      outputSizeBytes > 0 &&
      format.trim().isNotEmpty &&
      pixelWidth > 0 &&
      pixelHeight > 0;
}
