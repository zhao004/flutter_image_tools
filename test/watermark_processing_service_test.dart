import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_image_tools/app/services/watermark_processing_service.dart';
import 'package:flutter_image_tools/app/utils/watermark_layout.dart';

void main() {
  group('WatermarkProcessingService 水印合成', () {
    late Directory temporaryDirectory;

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'flutter_image_tools_palette_watermark_',
      );
    });

    tearDown(() {
      if (temporaryDirectory.existsSync()) {
        temporaryDirectory.deleteSync(recursive: true);
      }
    });

    test('索引色底图添加文字水印后写出实际合成结果', () async {
      // 调色板底图会让 image 包返回新的直接色彩图像；测试确保服务使用该返回值。
      final source = _createPaletteImage(
        width: 128,
        height: 96,
        red: 255,
        green: 255,
        blue: 255,
      );
      final overlay = img.Image(width: 12, height: 8, numChannels: 4)
        ..clear(img.ColorRgba8(255, 0, 0, 255));
      final sourceFile = _writePng(
        temporaryDirectory,
        'text_source.png',
        source,
      );
      final outputPath = _pathIn(temporaryDirectory, 'text_output.png');

      final result = await WatermarkProcessingService.addTextWatermark(
        sourcePath: sourceFile.path,
        textLayerPng: Uint8List.fromList(img.encodePng(overlay)),
        outputPath: outputPath,
        position: 'topleft',
        spacing: 24,
      );
      final output = _decodeOutput(result);
      final markedPixel = output.getPixel(
        WatermarkLayout.positionMarginPixels,
        WatermarkLayout.positionMarginPixels,
      );
      final untouchedPixel = output.getPixel(0, 0);

      expect(result['outputPath'], outputPath);
      expect(output.hasPalette, isFalse);
      expect(output.width, source.width);
      expect(output.height, source.height);
      expect(markedPixel.r, greaterThan(240));
      expect(markedPixel.g, lessThan(15));
      expect(markedPixel.b, lessThan(15));
      _expectWhite(untouchedPixel);
    });

    test('索引色水印图按设置透明度参与图片合成', () async {
      // 重复使用同一调色板索引可复现旧实现修改索引缓冲区导致水印消失的问题。
      final source = _createPaletteImage(
        width: 128,
        height: 96,
        red: 255,
        green: 255,
        blue: 255,
      );
      final watermark = _createPaletteImage(
        width: 4,
        height: 4,
        red: 0,
        green: 0,
        blue: 255,
      );
      final sourceFile = _writePng(
        temporaryDirectory,
        'image_source.png',
        source,
      );
      final watermarkFile = _writePng(
        temporaryDirectory,
        'palette_watermark.png',
        watermark,
      );
      final outputPath = _pathIn(temporaryDirectory, 'image_output.png');

      final result = await WatermarkProcessingService.addImageWatermark(
        sourcePath: sourceFile.path,
        watermarkPath: watermarkFile.path,
        outputPath: outputPath,
        position: 'bottomright',
        opacity: 50,
        scalePercent: 25,
        spacing: 24,
        rotationDegrees: 0,
      );
      final output = _decodeOutput(result);
      final targetSize = WatermarkLayout.imageWatermarkOutputSize(
        sourceWidth: source.width.toDouble(),
        sourceHeight: source.height.toDouble(),
        watermarkWidth: watermark.width.toDouble(),
        watermarkHeight: watermark.height.toDouble(),
        scalePercent: 25,
      );
      final markedPixel = output.getPixel(
        source.width -
            targetSize.roundedWidth -
            WatermarkLayout.positionMarginPixels,
        source.height -
            targetSize.roundedHeight -
            WatermarkLayout.positionMarginPixels,
      );

      expect(output.hasPalette, isFalse);
      expect(markedPixel.r, inInclusiveRange(120, 135));
      expect(markedPixel.g, inInclusiveRange(120, 135));
      expect(markedPixel.b, greaterThan(245));
      _expectWhite(output.getPixel(0, 0));
    });

    test('无 Alpha 通道的图片水印也会应用设置透明度', () async {
      // JPG 和部分 RGB PNG 没有 Alpha 通道，导出前必须扩展为 RGBA 才能写入透明度。
      final source = _createPaletteImage(
        width: 128,
        height: 96,
        red: 0,
        green: 0,
        blue: 0,
      );
      final watermark = img.Image(width: 8, height: 8, numChannels: 3)
        ..clear(img.ColorRgb8(255, 255, 255));
      final sourceFile = _writePng(
        temporaryDirectory,
        'rgb_opacity_source.png',
        source,
      );
      final watermarkFile = _writePng(
        temporaryDirectory,
        'rgb_opacity_watermark.png',
        watermark,
      );

      final result = await WatermarkProcessingService.addImageWatermark(
        sourcePath: sourceFile.path,
        watermarkPath: watermarkFile.path,
        outputPath: _pathIn(temporaryDirectory, 'rgb_opacity_output.png'),
        position: 'center',
        opacity: 50,
        scalePercent: 20,
        spacing: 8,
        rotationDegrees: 0,
      );

      expect(
        _maximumRedChannel(_decodeOutput(result)),
        inInclusiveRange(126, 129),
      );
    });

    test('透明底图合成后保留直通 RGB 和正确 Alpha', () async {
      // 50% 白色叠到全透明区域后应保存为 RGBA(255,255,255,128)，显示时再由
      // 查看器合成一次；若文件里写成预乘 RGB(128,128,128,128)，视觉会再次变淡。
      final source = img.Image(width: 64, height: 64, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 0));
      final overlay = img.Image(width: 8, height: 8, numChannels: 4)
        ..clear(img.ColorRgba8(255, 255, 255, 128));
      final sourceFile = _writePng(
        temporaryDirectory,
        'transparent_source.png',
        source,
      );

      final result = await WatermarkProcessingService.addTextWatermark(
        sourcePath: sourceFile.path,
        textLayerPng: Uint8List.fromList(img.encodePng(overlay)),
        outputPath: _pathIn(temporaryDirectory, 'transparent_output.png'),
        position: 'topleft',
        spacing: 8,
      );
      final markedPixel = _decodeOutput(result).getPixel(
        WatermarkLayout.positionMarginPixels,
        WatermarkLayout.positionMarginPixels,
      );

      expect(markedPixel.r, greaterThanOrEqualTo(254));
      expect(markedPixel.g, greaterThanOrEqualTo(254));
      expect(markedPixel.b, greaterThanOrEqualTo(254));
      expect(markedPixel.a, inInclusiveRange(127, 129));
    });

    test('索引色底图的平铺文字水印不会写回原图', () async {
      final source = _createPaletteImage(
        width: 96,
        height: 72,
        red: 255,
        green: 255,
        blue: 255,
      );
      final overlay = img.Image(width: 10, height: 6, numChannels: 4)
        ..clear(img.ColorRgba8(255, 0, 0, 255));
      final sourceFile = _writePng(
        temporaryDirectory,
        'tile_source.png',
        source,
      );
      final outputPath = _pathIn(temporaryDirectory, 'tile_output.png');

      final result = await WatermarkProcessingService.addTextWatermark(
        sourcePath: sourceFile.path,
        textLayerPng: Uint8List.fromList(img.encodePng(overlay)),
        outputPath: outputPath,
        position: 'tile',
        spacing: 8,
      );
      final output = _decodeOutput(result);

      expect(output.width, source.width);
      expect(output.height, source.height);
      expect(_nonWhitePixelCount(output), greaterThan(0));
    });

    test('文字和图片平铺水印的透明度只参与一次最终合成', () async {
      // 黑色底图上叠加 50% 白色水印，预览对应的最终通道值应接近 128。
      // 若透明中间层错误地预乘 RGB，第二次合成会降到约 64。
      final source = _createPaletteImage(
        width: 160,
        height: 120,
        red: 0,
        green: 0,
        blue: 0,
      );
      final textOverlay = img.Image(width: 24, height: 16, numChannels: 4)
        ..clear(img.ColorRgba8(255, 255, 255, 128));
      final imageWatermark = img.Image(width: 8, height: 8, numChannels: 4)
        ..clear(img.ColorRgba8(255, 255, 255, 255));
      final sourceFile = _writePng(
        temporaryDirectory,
        'opacity_source.png',
        source,
      );
      final imageWatermarkFile = _writePng(
        temporaryDirectory,
        'opacity_watermark.png',
        imageWatermark,
      );

      final textResult = await WatermarkProcessingService.addTextWatermark(
        sourcePath: sourceFile.path,
        textLayerPng: Uint8List.fromList(img.encodePng(textOverlay)),
        outputPath: _pathIn(temporaryDirectory, 'opacity_text_output.png'),
        position: 'tile',
        spacing: 8,
      );
      final imageResult = await WatermarkProcessingService.addImageWatermark(
        sourcePath: sourceFile.path,
        watermarkPath: imageWatermarkFile.path,
        outputPath: _pathIn(temporaryDirectory, 'opacity_image_output.png'),
        position: 'tile',
        opacity: 50,
        scalePercent: 20,
        spacing: 8,
        rotationDegrees: 0,
      );

      expect(
        _maximumRedChannel(_decodeOutput(textResult)),
        inInclusiveRange(126, 129),
      );
      expect(
        _maximumRedChannel(_decodeOutput(imageResult)),
        inInclusiveRange(126, 129),
      );
    });

    test('透明图片水印缩放后保持与预乘 Alpha 预览一致', () async {
      // 在黑色底图上，透明黑到不透明白的图形应与黑到白的不透明图形视觉等价。
      // 直通 RGBA 插值会把颜色和 Alpha 各缩放一次，在交界处形成明显暗边。
      final source = _createPaletteImage(
        width: 128,
        height: 128,
        red: 0,
        green: 0,
        blue: 0,
      );
      final transparentWatermark = img.Image(
        width: 8,
        height: 8,
        numChannels: 4,
      )..clear(img.ColorRgba8(0, 0, 0, 0));
      final opaqueEquivalent = img.Image(width: 8, height: 8, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 255));
      for (var y = 0; y < 8; y += 1) {
        for (var x = 4; x < 8; x += 1) {
          transparentWatermark.setPixelRgba(x, y, 255, 255, 255, 255);
          opaqueEquivalent.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
      final sourceFile = _writePng(
        temporaryDirectory,
        'alpha_resize_source.png',
        source,
      );
      final transparentFile = _writePng(
        temporaryDirectory,
        'alpha_resize_transparent.png',
        transparentWatermark,
      );
      final opaqueFile = _writePng(
        temporaryDirectory,
        'alpha_resize_opaque.png',
        opaqueEquivalent,
      );

      final transparentResult =
          await WatermarkProcessingService.addImageWatermark(
            sourcePath: sourceFile.path,
            watermarkPath: transparentFile.path,
            outputPath: _pathIn(
              temporaryDirectory,
              'alpha_resize_transparent_output.png',
            ),
            position: 'center',
            opacity: 100,
            scalePercent: 30,
            spacing: 8,
            rotationDegrees: 0,
          );
      final opaqueResult = await WatermarkProcessingService.addImageWatermark(
        sourcePath: sourceFile.path,
        watermarkPath: opaqueFile.path,
        outputPath: _pathIn(
          temporaryDirectory,
          'alpha_resize_opaque_output.png',
        ),
        position: 'center',
        opacity: 100,
        scalePercent: 30,
        spacing: 8,
        rotationDegrees: 0,
      );

      expect(
        _maximumRgbDifference(
          _decodeOutput(transparentResult),
          _decodeOutput(opaqueResult),
        ),
        lessThanOrEqualTo(2),
      );
    });

    test('十六位图片水印平铺时保持颜色和透明度比例', () async {
      final source = _createPaletteImage(
        width: 128,
        height: 96,
        red: 0,
        green: 0,
        blue: 0,
      );
      final watermark = img.Image(
        width: 8,
        height: 8,
        format: img.Format.uint16,
        numChannels: 3,
      );
      for (final pixel in watermark) {
        pixel
          ..rNormalized = 0.5
          ..gNormalized = 0.5
          ..bNormalized = 0.5;
      }
      final sourceFile = _writePng(
        temporaryDirectory,
        'uint16_opacity_source.png',
        source,
      );
      final watermarkFile = _writePng(
        temporaryDirectory,
        'uint16_opacity_watermark.png',
        watermark,
      );

      final result = await WatermarkProcessingService.addImageWatermark(
        sourcePath: sourceFile.path,
        watermarkPath: watermarkFile.path,
        outputPath: _pathIn(temporaryDirectory, 'uint16_opacity_output.png'),
        position: 'tile',
        opacity: 50,
        scalePercent: 20,
        spacing: 8,
        rotationDegrees: 0,
      );

      expect(
        _maximumRedChannel(_decodeOutput(result)),
        inInclusiveRange(62, 66),
      );
    });

    test('矩形图片水印旋转后按实际包围盒定位', () async {
      final source = _createPaletteImage(
        width: 160,
        height: 120,
        red: 255,
        green: 255,
        blue: 255,
      );
      final watermark = _createPaletteImage(
        width: 8,
        height: 4,
        red: 0,
        green: 0,
        blue: 255,
      );
      final sourceFile = _writePng(
        temporaryDirectory,
        'rotated_source.png',
        source,
      );
      final watermarkFile = _writePng(
        temporaryDirectory,
        'rotated_watermark.png',
        watermark,
      );
      final outputPath = _pathIn(temporaryDirectory, 'rotated_output.png');

      final result = await WatermarkProcessingService.addImageWatermark(
        sourcePath: sourceFile.path,
        watermarkPath: watermarkFile.path,
        outputPath: outputPath,
        position: 'bottomright',
        opacity: 100,
        scalePercent: 25,
        spacing: 24,
        rotationDegrees: 90,
      );
      final output = _decodeOutput(result);
      final baseSize = WatermarkLayout.imageWatermarkOutputSize(
        sourceWidth: source.width.toDouble(),
        sourceHeight: source.height.toDouble(),
        watermarkWidth: watermark.width.toDouble(),
        watermarkHeight: watermark.height.toDouble(),
        scalePercent: 25,
      );
      final rotatedSize = WatermarkLayout.rotatedOutputSize(
        width: baseSize.roundedWidth.toDouble(),
        height: baseSize.roundedHeight.toDouble(),
        rotationDegrees: 90,
      );
      final offset = WatermarkLayout.positionOffset(
        sourceWidth: source.width,
        sourceHeight: source.height,
        overlayWidth: rotatedSize.roundedWidth,
        overlayHeight: rotatedSize.roundedHeight,
        position: 'bottomright',
      );

      final markedPixel = output.getPixel(offset.x, offset.y);
      expect(markedPixel.r, lessThan(15));
      expect(markedPixel.g, lessThan(15));
      expect(markedPixel.b, greaterThan(240));
      _expectWhite(output.getPixel(offset.x - 1, offset.y));
    });
  });
}

img.Image _createPaletteImage({
  required int width,
  required int height,
  required int red,
  required int green,
  required int blue,
}) {
  final image = img.Image(
    width: width,
    height: height,
    numChannels: 4,
    withPalette: true,
  );
  image.palette!.setRgba(0, red, green, blue, 255);
  return image;
}

File _writePng(Directory directory, String name, img.Image image) {
  return File(_pathIn(directory, name))
    ..writeAsBytesSync(img.encodePng(image), flush: true);
}

img.Image _decodeOutput(Map<String, Object?> result) {
  final outputPath = result['outputPath'] as String?;
  expect(outputPath, isNotNull);
  final outputFile = File(outputPath!);
  expect(outputFile.existsSync(), isTrue);
  expect(outputFile.lengthSync(), greaterThan(0));
  final output = img.decodeImage(outputFile.readAsBytesSync());
  expect(output, isNotNull);
  return output!;
}

String _pathIn(Directory directory, String name) {
  return '${directory.path}${Platform.pathSeparator}$name';
}

void _expectWhite(img.Pixel pixel) {
  expect(pixel.r, 255);
  expect(pixel.g, 255);
  expect(pixel.b, 255);
}

int _nonWhitePixelCount(img.Image image) {
  return image.where((pixel) {
    return pixel.r != 255 || pixel.g != 255 || pixel.b != 255;
  }).length;
}

int _maximumRedChannel(img.Image image) {
  var maximum = 0;
  for (final pixel in image) {
    if (pixel.r > maximum) {
      maximum = pixel.r.toInt();
    }
  }
  return maximum;
}

int _maximumRgbDifference(img.Image first, img.Image second) {
  expect(first.width, second.width);
  expect(first.height, second.height);
  var maximum = 0;
  for (var y = 0; y < first.height; y += 1) {
    for (var x = 0; x < first.width; x += 1) {
      final firstPixel = first.getPixel(x, y);
      final secondPixel = second.getPixel(x, y);
      final difference = <int>[
        (firstPixel.r - secondPixel.r).abs().toInt(),
        (firstPixel.g - secondPixel.g).abs().toInt(),
        (firstPixel.b - secondPixel.b).abs().toInt(),
      ].reduce((value, element) => value > element ? value : element);
      if (difference > maximum) {
        maximum = difference;
      }
    }
  }
  return maximum;
}
