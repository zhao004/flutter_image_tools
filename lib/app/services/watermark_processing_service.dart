import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../exceptions/app_exception.dart';
import '../utils/watermark_layout.dart';

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
    final rawWatermark = _decodeStaticImage(watermarkPath);
    final targetSize = WatermarkLayout.imageWatermarkOutputSize(
      sourceWidth: image.width.toDouble(),
      sourceHeight: image.height.toDouble(),
      watermarkWidth: rawWatermark.width.toDouble(),
      watermarkHeight: rawWatermark.height.toDouble(),
      scalePercent: scalePercent,
    );
    var overlay = img.copyResize(
      rawWatermark,
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
  return img.compositeImage(image, overlay, dstX: offset.x, dstY: offset.y);
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
    numChannels: 4,
  )..clear(img.ColorRgba8(0, 0, 0, 0));
  for (final offset in tileLayout.offsets) {
    layer = img.compositeImage(layer, overlay, dstX: offset.x, dstY: offset.y);
  }
  final rotatedLayer = img.copyRotate(
    layer,
    angle: WatermarkLayout.tileRotationDegrees,
    interpolation: img.Interpolation.linear,
  );
  // 旋转层大于底图时，负目标坐标不会自动选择中心区域，必须先裁出可见画布。
  final visibleLayer = img.copyCrop(
    rotatedLayer,
    x: math.max(0, (rotatedLayer.width - image.width) ~/ 2),
    y: math.max(0, (rotatedLayer.height - image.height) ~/ 2),
    width: math.min(image.width, rotatedLayer.width),
    height: math.min(image.height, rotatedLayer.height),
  );
  return img.compositeImage(image, visibleLayer);
}

img.Image _applyOpacity(img.Image image, int opacity) {
  final directImage = _toDirectColorImage(image);
  final alphaScale = opacity.clamp(0, 100) / 100;
  for (final pixel in directImage) {
    pixel.a = (pixel.a * alphaScale).round().clamp(0, 255);
  }
  return directImage;
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
