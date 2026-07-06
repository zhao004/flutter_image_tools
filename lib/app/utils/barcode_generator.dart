import 'dart:typed_data';

import 'simple_png_encoder.dart';

class BarcodeRenderResult {
  const BarcodeRenderResult({
    required this.png,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final Uint8List png;
  final int pixelWidth;
  final int pixelHeight;
}

/// 本地 Code 128-B 条形码生成器，适合 ASCII 文本、编号和短链接。
///
/// 异常策略：仅接受可打印 ASCII 字符，避免生成扫码器无法稳定识别的内容；
/// 渲染使用固定高度和留白，输出 PNG 全程在本地完成。
class BarcodeGenerator {
  const BarcodeGenerator._();

  static const int maxContentLength = 80;
  static const int _startCodeB = 104;
  static const int _stopCode = 106;
  static const List<String> _patterns = [
    '212222',
    '222122',
    '222221',
    '121223',
    '121322',
    '131222',
    '122213',
    '122312',
    '132212',
    '221213',
    '221312',
    '231212',
    '112232',
    '122132',
    '122231',
    '113222',
    '123122',
    '123221',
    '223211',
    '221132',
    '221231',
    '213212',
    '223112',
    '312131',
    '311222',
    '321122',
    '321221',
    '312212',
    '322112',
    '322211',
    '212123',
    '212321',
    '232121',
    '111323',
    '131123',
    '131321',
    '112313',
    '132113',
    '132311',
    '211313',
    '231113',
    '231311',
    '112133',
    '112331',
    '132131',
    '113123',
    '113321',
    '133121',
    '313121',
    '211331',
    '231131',
    '213113',
    '213311',
    '213131',
    '311123',
    '311321',
    '331121',
    '312113',
    '312311',
    '332111',
    '314111',
    '221411',
    '431111',
    '111224',
    '111422',
    '121124',
    '121421',
    '141122',
    '141221',
    '112214',
    '112412',
    '122114',
    '122411',
    '142112',
    '142211',
    '241211',
    '221114',
    '413111',
    '241112',
    '134111',
    '111242',
    '121142',
    '121241',
    '114212',
    '124112',
    '124211',
    '411212',
    '421112',
    '421211',
    '212141',
    '214121',
    '412121',
    '111143',
    '111341',
    '131141',
    '114113',
    '114311',
    '411113',
    '411311',
    '113141',
    '114131',
    '311141',
    '411131',
    '211412',
    '211214',
    '211232',
    '2331112',
  ];

  static BarcodeRenderResult renderCode128Png(
    String content, {
    int moduleWidth = 3,
    int height = 160,
    int quietZoneModules = 10,
  }) {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('条形码内容不能为空');
    }
    if (normalized.length > maxContentLength) {
      throw ArgumentError('条形码内容不能超过 $maxContentLength 个字符');
    }
    if (moduleWidth < 1 || moduleWidth > 12) {
      throw ArgumentError('条形码模块宽度必须在 1 到 12 像素之间');
    }
    if (height < 80 || height > 600) {
      throw ArgumentError('条形码高度必须在 80 到 600 像素之间');
    }
    if (quietZoneModules < 4 || quietZoneModules > 40) {
      throw ArgumentError('条形码留白必须在 4 到 40 个模块之间');
    }

    final codes = _encodeCode128B(normalized);
    final modules = _codesToModules(codes);
    final quiet = quietZoneModules * moduleWidth;
    final pixelWidth = modules.length * moduleWidth + quiet * 2;
    final rgba = Uint8List(pixelWidth * height * 4);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < pixelWidth; x++) {
        final moduleIndex = (x - quiet) ~/ moduleWidth;
        final isDark =
            x >= quiet && moduleIndex >= 0 && moduleIndex < modules.length
            ? modules[moduleIndex]
            : false;
        final offset = (y * pixelWidth + x) * 4;
        final color = isDark ? 0 : 255;
        rgba[offset] = color;
        rgba[offset + 1] = color;
        rgba[offset + 2] = color;
        rgba[offset + 3] = 255;
      }
    }

    return BarcodeRenderResult(
      png: SimplePngEncoder.encodeRgba(
        width: pixelWidth,
        height: height,
        rgba: rgba,
      ),
      pixelWidth: pixelWidth,
      pixelHeight: height,
    );
  }

  static List<int> _encodeCode128B(String content) {
    final codes = <int>[_startCodeB];
    var checksum = _startCodeB;
    for (var index = 0; index < content.length; index++) {
      final unit = content.codeUnitAt(index);
      if (unit < 32 || unit > 126) {
        throw ArgumentError('条形码仅支持可打印 ASCII 字符');
      }
      final code = unit - 32;
      codes.add(code);
      checksum += code * (index + 1);
    }
    codes
      ..add(checksum % 103)
      ..add(_stopCode);
    return codes;
  }

  static List<bool> _codesToModules(List<int> codes) {
    final modules = <bool>[];
    for (final code in codes) {
      final pattern = _patterns[code];
      var isBar = true;
      for (final unit in pattern.codeUnits) {
        final width = unit - 48;
        modules.addAll(List<bool>.filled(width, isBar));
        isBar = !isBar;
      }
    }
    return modules;
  }
}
