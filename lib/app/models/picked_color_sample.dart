import 'dart:ui';

/// 图片取色结果模型，保存像素坐标、RGB、HEX 和 HSV 展示值。
///
/// 设计意图：颜色值由页面点击得到，模型集中负责格式化和边界收敛，避免
/// UI 层重复计算；透明度保留在模型中，后续可扩展透明图片取色提示。
class PickedColorSample {
  const PickedColorSample({
    required this.x,
    required this.y,
    required this.red,
    required this.green,
    required this.blue,
    required this.alpha,
  });

  final int x;
  final int y;
  final int red;
  final int green;
  final int blue;
  final int alpha;

  Color get color => Color.fromARGB(alpha, red, green, blue);

  String get rgbText => 'RGB($red, $green, $blue)';

  String get hexText {
    final value = (red << 16) + (green << 8) + blue;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  String get hsvText {
    final normalizedRed = red / 255;
    final normalizedGreen = green / 255;
    final normalizedBlue = blue / 255;
    final maxChannel = _max(normalizedRed, normalizedGreen, normalizedBlue);
    final minChannel = _min(normalizedRed, normalizedGreen, normalizedBlue);
    final delta = maxChannel - minChannel;
    final hue = _calculateHue(
      red: normalizedRed,
      green: normalizedGreen,
      blue: normalizedBlue,
      maxChannel: maxChannel,
      delta: delta,
    );
    final saturation = maxChannel == 0 ? 0 : delta / maxChannel;
    return 'HSV(${hue.toStringAsFixed(0)}°, '
        '${(saturation * 100).toStringAsFixed(0)}%, '
        '${(maxChannel * 100).toStringAsFixed(0)}%)';
  }

  double _calculateHue({
    required double red,
    required double green,
    required double blue,
    required double maxChannel,
    required double delta,
  }) {
    if (delta == 0) {
      return 0;
    }
    final hue = switch (maxChannel) {
      _ when maxChannel == red => 60 * (((green - blue) / delta) % 6),
      _ when maxChannel == green => 60 * (((blue - red) / delta) + 2),
      _ => 60 * (((red - green) / delta) + 4),
    };
    return hue < 0 ? hue + 360 : hue;
  }

  double _max(double first, double second, double third) {
    return first >= second && first >= third
        ? first
        : second >= third
        ? second
        : third;
  }

  double _min(double first, double second, double third) {
    return first <= second && first <= third
        ? first
        : second <= third
        ? second
        : third;
  }
}
