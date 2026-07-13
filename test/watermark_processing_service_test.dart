import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_image_tools/app/services/watermark_processing_service.dart';
import 'package:flutter_image_tools/app/utils/watermark_layout.dart';

void main() {
  group('WatermarkProcessingService 索引色图片处理', () {
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
