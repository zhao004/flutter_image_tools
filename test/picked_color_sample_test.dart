import 'package:flutter_image_tools/app/core/models/picked_color_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PickedColorSample', () {
    test('格式化红色 RGB、HEX 和 HSV', () {
      // 纯红色用于验证色相边界，避免 HSV 计算在主色通道处偏移。
      const sample = PickedColorSample(
        x: 4,
        y: 8,
        red: 255,
        green: 0,
        blue: 0,
        alpha: 255,
      );

      expect(sample.rgbText, 'RGB(255, 0, 0)');
      expect(sample.hexText, '#FF0000');
      expect(sample.hsvText, 'HSV(0°, 100%, 100%)');
    });

    test('格式化黑色 HSV 零饱和度和值', () {
      // 黑色没有明确色相，模型统一收敛到 0°，保证显示结果稳定。
      const sample = PickedColorSample(
        x: 0,
        y: 0,
        red: 0,
        green: 0,
        blue: 0,
        alpha: 255,
      );

      expect(sample.rgbText, 'RGB(0, 0, 0)');
      expect(sample.hexText, '#000000');
      expect(sample.hsvText, 'HSV(0°, 0%, 0%)');
    });
  });
}
