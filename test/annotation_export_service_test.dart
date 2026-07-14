import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_image_tools/app/exceptions/app_exception.dart';
import 'package:flutter_image_tools/app/models/image_edit_transform.dart';
import 'package:flutter_image_tools/app/services/local_image_channel.dart';

void main() {
  group('LocalImageChannel 图片编辑导出', () {
    final channel = LocalImageChannel();

    test('滤镜仅处理底图并保持标注原色', () {
      final source = img.Image(width: 2, height: 1, numChannels: 4)
        ..clear(img.ColorRgba8(20, 100, 240, 255));
      final overlay = img.Image(width: 2, height: 1, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 0))
        ..setPixelRgba(1, 0, 255, 0, 180, 255);

      final output = channel.processAnnotatedImage(
        source: source,
        overlay: overlay,
        transform: const ImageEditTransform(filter: 'grayscale'),
      );
      final filteredBackground = output.getPixel(0, 0);
      final annotationPixel = output.getPixel(1, 0);

      expect(filteredBackground.r, filteredBackground.g);
      expect(filteredBackground.g, filteredBackground.b);
      expect(annotationPixel.r, 255);
      expect(annotationPixel.g, 0);
      expect(annotationPixel.b, 180);
    });

    test('索引色底图使用合成函数返回的新图避免标注丢失', () {
      final source = img.Image(
        width: 2,
        height: 1,
        numChannels: 4,
        withPalette: true,
      );
      source.palette!.setRgba(0, 255, 255, 255, 255);
      final overlay = img.Image(width: 2, height: 1, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 0))
        ..setPixelRgba(1, 0, 255, 0, 0, 255);

      final output = channel.processAnnotatedImage(
        source: source,
        overlay: overlay,
        transform: const ImageEditTransform(),
      );

      expect(output.hasPalette, isFalse);
      expect(output.getPixel(0, 0).r, 255);
      expect(output.getPixel(1, 0).r, 255);
      expect(output.getPixel(1, 0).g, 0);
      expect(output.getPixel(1, 0).b, 0);
    });

    test('四十五度旋转结果尺寸与共享变换模型一致', () {
      final source = img.Image(width: 12, height: 8, numChannels: 4)
        ..clear(img.ColorRgba8(10, 20, 30, 255));
      final overlay = img.Image(width: 12, height: 8, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 0));
      const transform = ImageEditTransform(rotationDegrees: 45);

      final output = channel.processAnnotatedImage(
        source: source,
        overlay: overlay,
        transform: transform,
      );
      final expectedSize = transform.outputSizeFor(const Size(12, 8));

      expect(output.width, expectedSize.width.toInt());
      expect(output.height, expectedSize.height.toInt());
    });

    test('标注图层尺寸不一致时在合成前明确拒绝', () {
      final source = img.Image(width: 4, height: 4);
      final overlay = img.Image(width: 3, height: 4, numChannels: 4);

      expect(
        () => channel.processAnnotatedImage(
          source: source,
          overlay: overlay,
          transform: const ImageEditTransform(),
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            contains('尺寸'),
          ),
        ),
      );
    });
  });
}
