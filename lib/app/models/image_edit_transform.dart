import 'dart:math' as math;
import 'dart:ui';

/// 图片编辑资源边界，集中约束逻辑画布、预览缓存和全尺寸处理规模。
///
/// 设计意图：纯 Dart 图像处理会同时持有多个 RGBA 缓冲区，16MP 上限兼顾
/// 常见手机照片和低内存设备稳定性；超过边界时明确拒绝，不进行无提示降采样。
abstract final class ImageEditorLimits {
  static const int maxWorkingPixels = 16_000_000;
  static const int maxEncodedInputBytes = 64 * 1024 * 1024;
  static const int maxResizeDimension = 10_000;
  static const int previewMaxDimension = 2048;
  static const double logicalCanvasWidth = 1000;
}

/// 缩放输入来源，用于在上游几何变化时保持可预测的目标尺寸。
enum ImageEditResizeMode { none, percent, manual }

/// 手工缩放最后修改的轴；锁定比例时保留该轴并重新计算另一轴。
enum ImageEditDimensionAxis { width, height }

/// 图片编辑的不可变变换快照。
///
/// 处理顺序固定为：底图滤镜 -> 标注合成 -> 居中裁剪 -> 旋转 -> 翻转 -> 缩放。
/// 该对象同时服务预览几何和导出服务，避免两端分别推导尺寸。
class ImageEditTransform {
  const ImageEditTransform({
    this.filter,
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.resizeWidth,
    this.resizeHeight,
    this.cropAspectRatio,
  });

  final String? filter;
  final int rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;
  final int? resizeWidth;
  final int? resizeHeight;
  final double? cropAspectRatio;

  bool get hasResize => resizeWidth != null || resizeHeight != null;

  int get normalizedRotationDegrees {
    final normalized = rotationDegrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  /// 计算居中裁剪后的尺寸；非法比例由调用方校验，此处回退原尺寸。
  Size croppedSizeFor(Size sourceSize) {
    final safeSource = _positiveSize(sourceSize);
    final ratio = cropAspectRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) {
      return safeSource;
    }
    final sourceRatio = safeSource.width / safeSource.height;
    final usesPixelDimensions =
        safeSource.width == safeSource.width.roundToDouble() &&
        safeSource.height == safeSource.height.roundToDouble();
    if (sourceRatio > ratio) {
      final calculatedWidth = safeSource.height * ratio;
      final width = usesPixelDimensions
          ? calculatedWidth.roundToDouble()
          : calculatedWidth;
      return Size(width.clamp(1, safeSource.width), safeSource.height);
    }
    final calculatedHeight = safeSource.width / ratio;
    final height = usesPixelDimensions
        ? calculatedHeight.roundToDouble()
        : calculatedHeight;
    return Size(safeSource.width, height.clamp(1, safeSource.height));
  }

  /// 计算裁剪和旋转后的缩放基准，翻转不改变尺寸。
  Size preResizeSizeFor(Size sourceSize) {
    return rotatedSizeFor(
      croppedSizeFor(sourceSize),
      rotationDegrees: normalizedRotationDegrees,
    );
  }

  /// 计算最终输出尺寸；仅当宽高同时有效时采用显式缩放目标。
  Size outputSizeFor(Size sourceSize) {
    final beforeResize = preResizeSizeFor(sourceSize);
    final width = resizeWidth;
    final height = resizeHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return beforeResize;
    }
    return Size(width.toDouble(), height.toDouble());
  }

  /// 按导出引擎的包围盒取整规则计算任意角度旋转尺寸。
  static Size rotatedSizeFor(Size sourceSize, {required int rotationDegrees}) {
    final safeSource = _positiveSize(sourceSize);
    final normalized = rotationDegrees % 360;
    if (normalized % 90 == 0) {
      return normalized == 90 || normalized == 270
          ? Size(safeSource.height, safeSource.width)
          : safeSource;
    }
    final radians = normalized * math.pi / 180;
    final cosine = math.cos(radians).abs();
    final sine = math.sin(radians).abs();
    return Size(
      math
          .max(
            1,
            (safeSource.width * cosine + safeSource.height * sine).toInt(),
          )
          .toDouble(),
      math
          .max(
            1,
            (safeSource.width * sine + safeSource.height * cosine).toInt(),
          )
          .toDouble(),
    );
  }

  /// 返回处理阶段可能出现的最大像素数，用于在分配缓冲区前拒绝危险任务。
  int maximumIntermediatePixels(Size sourceSize) {
    final source = _positiveSize(sourceSize);
    final cropped = croppedSizeFor(source);
    final rotated = preResizeSizeFor(source);
    final output = outputSizeFor(source);
    return <Size>[
      source,
      cropped,
      rotated,
      output,
    ].map(_pixelCount).reduce(math.max);
  }

  static int _pixelCount(Size size) {
    return math.max(1, size.width.ceil()) * math.max(1, size.height.ceil());
  }

  static Size _positiveSize(Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return const Size(1, 1);
    }
    return size;
  }
}
