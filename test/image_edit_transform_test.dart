import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_image_tools/app/models/image_edit_transform.dart';

void main() {
  group('ImageEditTransform 图片编辑几何', () {
    test('任意角度旋转使用与导出引擎一致的包围盒', () {
      const sourceSize = Size(1200, 800);

      final rotated = ImageEditTransform.rotatedSizeFor(
        sourceSize,
        rotationDegrees: 45,
      );

      expect(rotated, const Size(1414, 1414));
      expect(
        ImageEditTransform.rotatedSizeFor(sourceSize, rotationDegrees: -90),
        const Size(800, 1200),
      );
    });

    test('裁剪旋转缩放按固定顺序推导最终尺寸', () {
      const transform = ImageEditTransform(
        cropAspectRatio: 1,
        rotationDegrees: 45,
        resizeWidth: 320,
        resizeHeight: 240,
      );
      const sourceSize = Size(1200, 800);

      expect(transform.croppedSizeFor(sourceSize), const Size(800, 800));
      expect(transform.preResizeSizeFor(sourceSize), const Size(1131, 1131));
      expect(transform.outputSizeFor(sourceSize), const Size(320, 240));
    });

    test('像素尺寸裁剪复刻导出引擎的整数取整', () {
      const transform = ImageEditTransform(cropAspectRatio: 1.2);

      expect(transform.croppedSizeFor(const Size(5, 4)), const Size(5, 4));
      expect(
        transform.croppedSizeFor(const Size(1000, 600)),
        const Size(720, 600),
      );
    });

    test('像素预算包含源图和任意角度旋转中间结果', () {
      const transform = ImageEditTransform(rotationDegrees: 45);

      expect(
        transform.maximumIntermediatePixels(const Size(4000, 4000)),
        greaterThan(ImageEditorLimits.maxWorkingPixels),
      );
      expect(
        const ImageEditTransform().maximumIntermediatePixels(
          const Size(4000, 4000),
        ),
        ImageEditorLimits.maxWorkingPixels,
      );
    });

    test('缩放宽高不完整或非法时保持变换前尺寸', () {
      const sourceSize = Size(640, 480);

      expect(
        const ImageEditTransform(resizeWidth: 320).outputSizeFor(sourceSize),
        sourceSize,
      );
      expect(
        const ImageEditTransform(
          resizeWidth: 0,
          resizeHeight: 240,
        ).outputSizeFor(sourceSize),
        sourceSize,
      );
    });
  });
}
