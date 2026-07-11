import 'dart:math' as math;

/// 水印布局计算工具，统一预览层和导出层对尺寸、边距与缩放的理解。
///
/// 设计意图：UI 预览使用逻辑像素，导出使用图片原始像素；这里集中完成比例换算，
/// 避免同一组滑杆参数在预览和最终图片中呈现不同大小。异常策略：所有外部尺寸
/// 都会先收敛到正数，避免损坏元数据或 0 尺寸图片导致除零。
class WatermarkLayout {
  const WatermarkLayout._();

  static const int minImageScalePercent = 5;
  static const int maxImageScalePercent = 100;
  static const int positionMarginPixels = 24;
  static const double minimumPreviewPixels = 1;

  static WatermarkSize imageWatermarkOutputSize({
    required double sourceWidth,
    required double sourceHeight,
    required double watermarkWidth,
    required double watermarkHeight,
    required int scalePercent,
  }) {
    final safeSourceWidth = _positive(sourceWidth);
    final safeSourceHeight = _positive(sourceHeight);
    final safeWatermarkWidth = _positive(watermarkWidth);
    final safeWatermarkHeight = _positive(watermarkHeight);
    final safeScale = scalePercent.clamp(
      minImageScalePercent,
      maxImageScalePercent,
    );
    final targetWidth = safeSourceWidth * safeScale / 100;
    final targetHeight = safeSourceHeight * safeScale / 100;
    final ratio = math.min(
      targetWidth / safeWatermarkWidth,
      targetHeight / safeWatermarkHeight,
    );
    final safeRatio = ratio.isFinite && ratio > 0 ? ratio : 1.0;
    return WatermarkSize(
      width: math.max(minimumPreviewPixels, safeWatermarkWidth * safeRatio),
      height: math.max(minimumPreviewPixels, safeWatermarkHeight * safeRatio),
    );
  }

  static WatermarkSize imageWatermarkPreviewSize({
    required double sourceWidth,
    required double sourceHeight,
    required double watermarkWidth,
    required double watermarkHeight,
    required double previewWidth,
    required double previewHeight,
    required int scalePercent,
  }) {
    final outputSize = imageWatermarkOutputSize(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      watermarkWidth: watermarkWidth,
      watermarkHeight: watermarkHeight,
      scalePercent: scalePercent,
    );
    final scale = previewScale(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );
    return outputSize.scale(scale);
  }

  static double previewScale({
    required double sourceWidth,
    required double sourceHeight,
    required double previewWidth,
    required double previewHeight,
  }) {
    final safeSourceWidth = _positive(sourceWidth);
    final safeSourceHeight = _positive(sourceHeight);
    final safePreviewWidth = _positive(previewWidth);
    final safePreviewHeight = _positive(previewHeight);
    final scale = math.min(
      safePreviewWidth / safeSourceWidth,
      safePreviewHeight / safeSourceHeight,
    );
    return scale.isFinite && scale > 0 ? scale : 1.0;
  }

  static double outputPixelsToPreview({
    required int outputPixels,
    required double sourceWidth,
    required double sourceHeight,
    required double previewWidth,
    required double previewHeight,
  }) {
    final scale = previewScale(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );
    return math.max(minimumPreviewPixels, outputPixels * scale);
  }

  static double _positive(double value) {
    return value.isFinite && value > 0 ? value : minimumPreviewPixels;
  }
}

/// 水印宽高值对象，避免在服务层和 UI 层重复传递松散的双元素数组。
class WatermarkSize {
  const WatermarkSize({required this.width, required this.height});

  final double width;
  final double height;

  int get roundedWidth => math.max(1, width.round());

  int get roundedHeight => math.max(1, height.round());

  WatermarkSize scale(double ratio) {
    final safeRatio = ratio.isFinite && ratio > 0 ? ratio : 1.0;
    return WatermarkSize(
      width: math.max(WatermarkLayout.minimumPreviewPixels, width * safeRatio),
      height: math.max(
        WatermarkLayout.minimumPreviewPixels,
        height * safeRatio,
      ),
    );
  }
}
