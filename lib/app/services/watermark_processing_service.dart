import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../exceptions/app_exception.dart';
import '../utils/watermark_layout.dart';
import '../utils/watermark_opacity.dart';

/// 后台水印处理服务，负责在独立 isolate 中完成解码、合成和 PNG 编码。
///
/// 设计意图：水印导出会遍历大量像素，尤其是平铺水印和 PNG 编码容易阻塞主
/// isolate；这里只把纯 Dart 图像处理放到后台，文字图层仍由 UI isolate
/// 先渲染为 PNG，兼顾性能与 Flutter 文本渲染兼容性。
class WatermarkProcessingService {
  const WatermarkProcessingService._();

  static const int maxDecodedPixels = 120000000;

  static Future<Map<String, Object?>> addTextWatermark({
    required String sourcePath,
    required Uint8List textLayerPng,
    required String outputPath,
    required String position,
    required int spacing,
  }) async {
    final arguments = <String, Object?>{
      'sourcePath': sourcePath,
      'textLayerPng': textLayerPng,
      'outputPath': outputPath,
      'position': position,
      'spacing': spacing,
    };
    final result = await Isolate.run(() => _addTextWatermarkTask(arguments));
    return _requireSuccess(result, fallbackMessage: '添加文字水印失败，请重试');
  }

  static Future<Map<String, Object?>> addImageWatermark({
    required String sourcePath,
    required String watermarkPath,
    required String outputPath,
    required String position,
    required int opacity,
    required int scalePercent,
    required int spacing,
    required int rotationDegrees,
  }) async {
    final arguments = <String, Object?>{
      'sourcePath': sourcePath,
      'watermarkPath': watermarkPath,
      'outputPath': outputPath,
      'position': position,
      'opacity': opacity,
      'scalePercent': scalePercent,
      'spacing': spacing,
      'rotationDegrees': rotationDegrees,
    };
    final result = await Isolate.run(() => _addImageWatermarkTask(arguments));
    return _requireSuccess(result, fallbackMessage: '添加图片水印失败，请重试');
  }

  static Map<String, Object?> _requireSuccess(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    if (result['ok'] != true) {
      throw AppException(result['message'] as String? ?? fallbackMessage);
    }
    return result;
  }
}

Map<String, Object?> _addTextWatermarkTask(Map<String, Object?> arguments) {
  return _guardWatermarkTask(() {
    final sourcePath = arguments['sourcePath'] as String;
    final textLayerPng = arguments['textLayerPng'] as Uint8List;
    final outputPath = arguments['outputPath'] as String;
    final position = arguments['position'] as String;
    final spacing = arguments['spacing'] as int;
    var image = _decodeStaticImage(sourcePath);
    final decodedOverlay = img.decodePng(textLayerPng);
    if (decodedOverlay == null ||
        decodedOverlay.width <= 0 ||
        decodedOverlay.height <= 0) {
      throw const _WatermarkTaskException('文字水印渲染结果异常，请重试');
    }
    final overlay = _toDirectColorImage(decodedOverlay);
    image = _compositeWatermark(
      image: image,
      overlay: overlay,
      position: position,
      spacing: spacing,
    );

    final output = _writePngOutput(outputPath, image);
    return <String, Object?>{
      'ok': true,
      'outputPath': output.path,
      'outputSizeBytes': output.lengthSync(),
    };
  });
}

Map<String, Object?> _addImageWatermarkTask(Map<String, Object?> arguments) {
  return _guardWatermarkTask(() {
    final sourcePath = arguments['sourcePath'] as String;
    final watermarkPath = arguments['watermarkPath'] as String;
    final outputPath = arguments['outputPath'] as String;
    final position = arguments['position'] as String;
    final opacity = arguments['opacity'] as int;
    final scalePercent = arguments['scalePercent'] as int;
    final spacing = arguments['spacing'] as int;
    final rotationDegrees = arguments['rotationDegrees'] as int;
    var image = _decodeStaticImage(sourcePath);
    var overlay = _toRgbaImage(_decodeStaticImage(watermarkPath));
    final targetSize = WatermarkLayout.imageWatermarkOutputSize(
      sourceWidth: image.width.toDouble(),
      sourceHeight: image.height.toDouble(),
      watermarkWidth: overlay.width.toDouble(),
      watermarkHeight: overlay.height.toDouble(),
      scalePercent: scalePercent,
    );
    // Flutter 以预乘 Alpha 采样透明图片；导出侧在缩放、旋转期间使用相同表示，
    // 避免透明边缘的 RGB 和 Alpha 被分别插值后在最终合成时重复衰减。
    final hasTransparency = _premultiplyAlpha(overlay);
    overlay = img.copyResize(
      overlay,
      width: targetSize.roundedWidth,
      height: targetSize.roundedHeight,
      interpolation: img.Interpolation.linear,
    );
    if (rotationDegrees != 0) {
      overlay = img.copyRotate(
        overlay,
        angle: rotationDegrees,
        interpolation: img.Interpolation.linear,
      );
    }
    if (hasTransparency) {
      overlay = _unpremultiplyAlpha(overlay);
    }
    overlay = _applyOpacity(overlay, opacity);
    image = _compositeWatermark(
      image: image,
      overlay: overlay,
      position: position,
      spacing: spacing,
    );

    final output = _writePngOutput(outputPath, image);
    return <String, Object?>{
      'ok': true,
      'outputPath': output.path,
      'outputSizeBytes': output.lengthSync(),
    };
  });
}

img.Image _decodeStaticImage(String path) {
  final file = _requireInputFile(path);
  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const _WatermarkTaskException('图片格式不支持或文件已损坏');
  }
  if (decoded.width * decoded.height >
      WatermarkProcessingService.maxDecodedPixels) {
    throw const _WatermarkTaskException('图片尺寸过大，请先缩小后再处理');
  }
  final staticImage = img.Image.from(decoded, noAnimation: true);
  return _toDirectColorImage(staticImage);
}

/// 将索引色图片展开为直接色彩，避免后续合成返回新对象或透明度修改落到索引数据。
img.Image _toDirectColorImage(img.Image image) {
  if (!image.hasPalette) {
    return image;
  }
  return image.convert(numChannels: image.numChannels, noAnimation: true);
}

/// 确保水印具有可写 Alpha 通道；JPG 和部分 PNG 解码后只有 RGB 三通道。
img.Image _toRgbaImage(img.Image image) {
  final directImage = _toDirectColorImage(image);
  if (directImage.numChannels == 4) {
    return directImage;
  }
  return directImage.convert(numChannels: 4, noAnimation: true);
}

File _requireInputFile(String path) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw const _WatermarkTaskException('图片路径为空，请重新选择图片');
  }
  final file = File(normalizedPath);
  if (!file.existsSync()) {
    throw const _WatermarkTaskException('图片文件不存在，请重新选择');
  }
  if (file.lengthSync() <= 0) {
    throw const _WatermarkTaskException('图片文件为空，请重新选择');
  }
  return file;
}

img.Image _compositeWatermark({
  required img.Image image,
  required img.Image overlay,
  required String position,
  required int spacing,
}) {
  if (position == 'tile') {
    return _drawTiledWatermark(image, overlay, spacing);
  }
  final offset = WatermarkLayout.positionOffset(
    sourceWidth: image.width,
    sourceHeight: image.height,
    overlayWidth: overlay.width,
    overlayHeight: overlay.height,
    position: position,
  );
  return _compositeSourceOver(
    destination: image,
    source: overlay,
    destinationX: offset.x,
    destinationY: offset.y,
  );
}

img.Image _drawTiledWatermark(img.Image image, img.Image overlay, int spacing) {
  final tileLayout = WatermarkLayout.tileOutputLayout(
    sourceWidth: image.width,
    sourceHeight: image.height,
    overlayWidth: overlay.width,
    overlayHeight: overlay.height,
    spacing: spacing,
  );
  var layer = img.Image(
    width: tileLayout.layerSize,
    height: tileLayout.layerSize,
    format: overlay.format,
    numChannels: 4,
  )..clear(img.ColorRgba8(0, 0, 0, 0));
  for (final offset in tileLayout.offsets) {
    // 平铺单元的包围盒由正间距隔开，不会互相覆盖。直接复制可保留直通 Alpha，
    // 避免 image 包先在透明层预乘 RGB、最终合成时再次乘 Alpha 导致透明度平方。
    layer = _copyImageDirect(
      destination: layer,
      source: overlay,
      destinationX: offset.x,
      destinationY: offset.y,
    );
  }
  final hasTransparency = _premultiplyAlpha(layer);
  var rotatedLayer = img.copyRotate(
    layer,
    angle: WatermarkLayout.tileRotationDegrees,
    interpolation: img.Interpolation.linear,
  );
  if (hasTransparency) {
    rotatedLayer = _unpremultiplyAlpha(rotatedLayer);
  }
  // 旋转层大于底图时，负目标坐标不会自动选择中心区域，必须先裁出可见画布。
  final visibleLayer = img.copyCrop(
    rotatedLayer,
    x: math.max(0, (rotatedLayer.width - image.width) ~/ 2),
    y: math.max(0, (rotatedLayer.height - image.height) ~/ 2),
    width: math.min(image.width, rotatedLayer.width),
    height: math.min(image.height, rotatedLayer.height),
  );
  return _compositeSourceOver(destination: image, source: visibleLayer);
}

/// 使用 Porter-Duff Source-over 把直通 Alpha 源图合成到目标图。
///
/// `image 4.9.1` 的默认合成会把预乘 RGB 直接写进直通 Alpha 图片；目标区域
/// 透明时，保存并再次显示会重复衰减颜色。这里除以输出 Alpha 恢复直通 RGB，
/// 并在循环前裁掉所有越界区域。灰度目标图会扩展为 RGBA 以保留彩色水印。
img.Image _compositeSourceOver({
  required img.Image destination,
  required img.Image source,
  int destinationX = 0,
  int destinationY = 0,
}) {
  var output = _toDirectColorImage(destination);
  if (output.numChannels < 3) {
    output = output.convert(numChannels: 4, noAnimation: true);
  }
  final sourceX = math.max(0, -destinationX);
  final sourceY = math.max(0, -destinationY);
  final safeDestinationX = math.max(0, destinationX);
  final safeDestinationY = math.max(0, destinationY);
  final copyWidth = math.min(
    source.width - sourceX,
    output.width - safeDestinationX,
  );
  final copyHeight = math.min(
    source.height - sourceY,
    output.height - safeDestinationY,
  );
  if (copyWidth <= 0 || copyHeight <= 0) {
    return output;
  }

  for (var y = 0; y < copyHeight; y += 1) {
    for (var x = 0; x < copyWidth; x += 1) {
      final sourcePixel = source.getPixel(sourceX + x, sourceY + y);
      final sourceAlpha = sourcePixel.aNormalized.clamp(0, 1).toDouble();
      if (sourceAlpha <= 0) {
        continue;
      }
      final destinationPixel = output.getPixel(
        safeDestinationX + x,
        safeDestinationY + y,
      );
      if (sourceAlpha >= 1) {
        destinationPixel
          ..rNormalized = sourcePixel.rNormalized
          ..gNormalized = sourcePixel.gNormalized
          ..bNormalized = sourcePixel.bNormalized
          ..aNormalized = sourcePixel.aNormalized;
        continue;
      }
      final destinationAlpha = destinationPixel.aNormalized
          .clamp(0, 1)
          .toDouble();
      final inverseSourceAlpha = 1 - sourceAlpha;
      final outputAlpha = sourceAlpha + destinationAlpha * inverseSourceAlpha;
      if (outputAlpha <= 0) {
        destinationPixel
          ..rNormalized = 0
          ..gNormalized = 0
          ..bNormalized = 0
          ..aNormalized = 0;
        continue;
      }
      final destinationWeight = destinationAlpha * inverseSourceAlpha;
      destinationPixel
        ..rNormalized =
            (sourcePixel.rNormalized * sourceAlpha +
                destinationPixel.rNormalized * destinationWeight) /
            outputAlpha
        ..gNormalized =
            (sourcePixel.gNormalized * sourceAlpha +
                destinationPixel.gNormalized * destinationWeight) /
            outputAlpha
        ..bNormalized =
            (sourcePixel.bNormalized * sourceAlpha +
                destinationPixel.bNormalized * destinationWeight) /
            outputAlpha
        ..aNormalized = outputAlpha;
    }
  }
  return output;
}

/// 将源图直通复制到目标图，并在复制前裁掉目标画布之外的区域。
///
/// `image` 包的 direct 合成不会自动忽略负目标坐标，而平铺为覆盖旋转边缘必须从
/// 负坐标起步；这里统一裁剪源区域，越界或空交集直接保持目标图不变。
img.Image _copyImageDirect({
  required img.Image destination,
  required img.Image source,
  required int destinationX,
  required int destinationY,
}) {
  final sourceX = math.max(0, -destinationX);
  final sourceY = math.max(0, -destinationY);
  final safeDestinationX = math.max(0, destinationX);
  final safeDestinationY = math.max(0, destinationY);
  final copyWidth = math.min(
    source.width - sourceX,
    destination.width - safeDestinationX,
  );
  final copyHeight = math.min(
    source.height - sourceY,
    destination.height - safeDestinationY,
  );
  if (copyWidth <= 0 || copyHeight <= 0) {
    return destination;
  }
  return img.compositeImage(
    destination,
    source,
    dstX: safeDestinationX,
    dstY: safeDestinationY,
    dstW: copyWidth,
    dstH: copyHeight,
    srcX: sourceX,
    srcY: sourceY,
    srcW: copyWidth,
    srcH: copyHeight,
    blend: img.BlendMode.direct,
  );
}

/// 就地把直通 RGB 转为预乘 Alpha，并返回图片是否含透明像素。
///
/// 全不透明或无 Alpha 通道的图片无需恢复，可跳过后续除法。全透明像素的 RGB
/// 归零，避免不可见颜色在插值后形成色边。
bool _premultiplyAlpha(img.Image image) {
  if (image.numChannels < 4) {
    return false;
  }
  var hasTransparency = false;
  for (final pixel in image) {
    final alpha = pixel.aNormalized.clamp(0, 1).toDouble();
    if (alpha >= 1) {
      continue;
    }
    hasTransparency = true;
    if (alpha <= 0) {
      pixel
        ..r = 0
        ..g = 0
        ..b = 0;
      continue;
    }
    final red = pixel.rNormalized;
    final green = pixel.gNormalized;
    final blue = pixel.bNormalized;
    pixel
      ..rNormalized = red * alpha
      ..gNormalized = green * alpha
      ..bNormalized = blue * alpha;
  }
  return hasTransparency;
}

/// 就地把重采样后的预乘颜色恢复为 PNG 和合成函数需要的直通 Alpha。
img.Image _unpremultiplyAlpha(img.Image image) {
  if (image.numChannels < 4) {
    return image;
  }
  for (final pixel in image) {
    final alpha = pixel.aNormalized.clamp(0, 1).toDouble();
    if (alpha <= 0) {
      pixel
        ..r = 0
        ..g = 0
        ..b = 0;
      continue;
    }
    if (alpha >= 1) {
      continue;
    }
    final red = pixel.rNormalized;
    final green = pixel.gNormalized;
    final blue = pixel.bNormalized;
    pixel
      ..rNormalized = (red / alpha).clamp(0, 1)
      ..gNormalized = (green / alpha).clamp(0, 1)
      ..bNormalized = (blue / alpha).clamp(0, 1);
  }
  return image;
}

img.Image _applyOpacity(img.Image image, int opacity) {
  final rgbaImage = _toRgbaImage(image);
  for (final pixel in rgbaImage) {
    pixel.aNormalized = WatermarkOpacity.scaleNormalizedAlpha(
      pixel.aNormalized,
      opacity,
    );
  }
  return rgbaImage;
}

File _writePngOutput(String outputPath, img.Image image) {
  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(img.encodePng(image), flush: true);
  if (!output.existsSync() || output.lengthSync() <= 0) {
    throw const _WatermarkTaskException('水印文件写入失败，请检查存储空间');
  }
  return output;
}

Map<String, Object?> _guardWatermarkTask(
  Map<String, Object?> Function() operation,
) {
  try {
    return operation();
  } on _WatermarkTaskException catch (error) {
    return <String, Object?>{'ok': false, 'message': error.message};
  } on FileSystemException {
    return <String, Object?>{'ok': false, 'message': '文件读写失败，请检查存储空间和文件权限'};
  } catch (_) {
    return <String, Object?>{'ok': false, 'message': '水印处理失败，请重试'};
  }
}

class _WatermarkTaskException implements Exception {
  const _WatermarkTaskException(this.message);

  final String message;
}
