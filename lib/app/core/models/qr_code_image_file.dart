/// 二维码生成结果模型，记录输入文本、导出图片和矩阵信息。
///
/// 设计意图：二维码由 Dart 本地生成，模型保留版本和模块数量，方便界面展示
/// 导出质量；内容摘要只保留原始文本，后续历史记录可据此重新生成。
class QrCodeImageFile {
  const QrCodeImageFile({
    required this.content,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.version,
    required this.moduleCount,
    required this.pixelSize,
  });

  final String content;
  final String outputPath;
  final int outputSizeBytes;
  final int version;
  final int moduleCount;
  final int pixelSize;

  bool get hasValidOutput =>
      outputPath.trim().isNotEmpty &&
      outputSizeBytes > 0 &&
      version > 0 &&
      moduleCount > 0 &&
      pixelSize > 0;
}
