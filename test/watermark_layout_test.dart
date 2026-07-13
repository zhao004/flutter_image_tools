import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_image_tools/app/utils/watermark_layout.dart';

void main() {
  group('WatermarkLayout 预览与导出共享几何', () {
    test('旋转包围盒遵循导出引擎的正交与任意角度取整', () {
      final orthogonal = WatermarkLayout.rotatedOutputSize(
        width: 120,
        height: 60,
        rotationDegrees: 90,
      );
      final diagonal = WatermarkLayout.rotatedOutputSize(
        width: 120,
        height: 60,
        rotationDegrees: 45,
      );

      expect(orthogonal.roundedWidth, 60);
      expect(orthogonal.roundedHeight, 120);
      expect(diagonal.roundedWidth, 127);
      expect(diagonal.roundedHeight, 127);
    });

    test('旋转后的右下角位置使用实际包围盒计算', () {
      final offset = WatermarkLayout.positionOffset(
        sourceWidth: 300,
        sourceHeight: 200,
        overlayWidth: 80,
        overlayHeight: 50,
        position: 'bottomRight',
      );

      expect(offset.x, 196);
      expect(offset.y, 126);
    });

    test('平铺画布统一横纵步长、间距边界和交错起点', () {
      final layout = WatermarkLayout.tileOutputLayout(
        sourceWidth: 100,
        sourceHeight: 80,
        overlayWidth: 20,
        overlayHeight: 10,
        spacing: 0,
      );
      final offsets = layout.offsets.take(10).toList(growable: false);

      expect(layout.stepX, 28);
      expect(layout.stepY, 18);
      expect(layout.layerSize, 185);
      expect(offsets[0].x, -28);
      expect(offsets[0].y, 0);
      expect(offsets[1].x, 0);
      expect(offsets[9].x, -14);
      expect(offsets[9].y, 18);
    });
  });
}
