import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_image_tools/app/utils/watermark_opacity.dart';

void main() {
  group('WatermarkOpacity 透明度换算', () {
    test('百分比统一收敛并转换为预览因子', () {
      expect(WatermarkOpacity.factorFromPercent(-20), 0);
      expect(WatermarkOpacity.factorFromPercent(40), 0.4);
      expect(WatermarkOpacity.factorFromPercent(120), 1);
    });

    test('百分比统一转换为八位 Alpha', () {
      expect(WatermarkOpacity.alphaFromPercent(40), 102);
      expect(WatermarkOpacity.alphaFromPercent(50), 128);
      expect(WatermarkOpacity.alphaFromPercent(100), 255);
    });

    test('图片原有 Alpha 与用户透明度只相乘一次', () {
      expect(WatermarkOpacity.scaleAlpha(255, 50), 128);
      expect(WatermarkOpacity.scaleAlpha(128, 50), 64);
      expect(WatermarkOpacity.scaleAlpha(double.nan, 50), 0);
      expect(WatermarkOpacity.scaleNormalizedAlpha(0.5, 40), 0.2);
      expect(WatermarkOpacity.scaleNormalizedAlpha(double.infinity, 40), 0);
    });
  });
}
