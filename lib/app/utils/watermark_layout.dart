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
  static const int minSpacingPixels = 8;
  static const int maxSpacingPixels = 160;
  static const int tileRotationDegrees = -30;
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

  /// 按导出引擎的取整规则计算旋转后的像素包围盒。
  static WatermarkSize rotatedOutputSize({
    required double width,
    required double height,
    required int rotationDegrees,
  }) {
    final safeWidth = _positive(width);
    final safeHeight = _positive(height);
    final normalizedDegrees = rotationDegrees % 360;
    if (normalizedDegrees % 90 == 0) {
      return normalizedDegrees == 90 || normalizedDegrees == 270
          ? WatermarkSize(width: safeHeight, height: safeWidth)
          : WatermarkSize(width: safeWidth, height: safeHeight);
    }
    final radians = normalizedDegrees * math.pi / 180;
    final cosine = math.cos(radians).abs();
    final sine = math.sin(radians).abs();
    return WatermarkSize(
      width: math.max(
        minimumPreviewPixels,
        (safeWidth * cosine + safeHeight * sine).toInt().toDouble(),
      ),
      height: math.max(
        minimumPreviewPixels,
        (safeWidth * sine + safeHeight * cosine).toInt().toDouble(),
      ),
    );
  }

  /// 计算非平铺水印的导出落点，位置值使用服务层的全小写稳定字符串。
  static WatermarkOffset positionOffset({
    required int sourceWidth,
    required int sourceHeight,
    required int overlayWidth,
    required int overlayHeight,
    required String position,
  }) {
    const margin = positionMarginPixels;
    return switch (position.trim().toLowerCase()) {
      'topleft' => const WatermarkOffset(margin, margin),
      'topright' => WatermarkOffset(
        math.max(margin, sourceWidth - overlayWidth - margin),
        margin,
      ),
      'bottomleft' => WatermarkOffset(
        margin,
        math.max(margin, sourceHeight - overlayHeight - margin),
      ),
      'bottomright' => WatermarkOffset(
        math.max(margin, sourceWidth - overlayWidth - margin),
        math.max(margin, sourceHeight - overlayHeight - margin),
      ),
      _ => WatermarkOffset(
        math.max(0, (sourceWidth - overlayWidth) ~/ 2),
        math.max(0, (sourceHeight - overlayHeight) ~/ 2),
      ),
    };
  }

  /// 创建预览和导出共用的平铺画布，避免两端采用不同步长或起点。
  static WatermarkTileLayout tileOutputLayout({
    required int sourceWidth,
    required int sourceHeight,
    required int overlayWidth,
    required int overlayHeight,
    required int spacing,
  }) {
    final safeSourceWidth = math.max(1, sourceWidth);
    final safeSourceHeight = math.max(1, sourceHeight);
    final safeOverlayWidth = math.max(1, overlayWidth);
    final safeOverlayHeight = math.max(1, overlayHeight);
    final safeSpacing = spacing.clamp(minSpacingPixels, maxSpacingPixels);
    final stepX = safeOverlayWidth + safeSpacing;
    final stepY = safeOverlayHeight + safeSpacing;
    final layerSize =
        math
            .sqrt(
              safeSourceWidth * safeSourceWidth +
                  safeSourceHeight * safeSourceHeight,
            )
            .ceil() +
        math.max(stepX, stepY) * 2;
    return WatermarkTileLayout(
      layerSize: layerSize,
      stepX: stepX,
      stepY: stepY,
    );
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

/// 水印在原图坐标系中的整数偏移。
class WatermarkOffset {
  const WatermarkOffset(this.x, this.y);

  final int x;
  final int y;
}

/// 平铺水印的公共画布参数，并按导出顺序提供每个水印落点。
class WatermarkTileLayout {
  const WatermarkTileLayout({
    required this.layerSize,
    required this.stepX,
    required this.stepY,
  });

  final int layerSize;
  final int stepX;
  final int stepY;

  Iterable<WatermarkOffset> get offsets sync* {
    var row = 0;
    for (var y = 0; y < layerSize + stepY; y += stepY) {
      final rowOffset = row.isOdd ? stepX ~/ 2 : 0;
      for (var x = -stepX; x < layerSize + stepX; x += stepX) {
        yield WatermarkOffset(x + rowOffset, y);
      }
      row += 1;
    }
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
