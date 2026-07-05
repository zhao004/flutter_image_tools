import 'dart:convert';
import 'dart:typed_data';

import 'simple_png_encoder.dart';

class QrCodeMatrix {
  const QrCodeMatrix({required this.version, required this.modules});

  final int version;
  final List<List<bool>> modules;

  int get size => modules.length;
}

/// 本地二维码生成器，支持 Byte 模式、L 级纠错和版本 1 到 4。
///
/// 设计意图：先覆盖文本、链接、短备注等常见离线二维码生成场景；实现完整的
/// Reed-Solomon 纠错与掩膜选择，保证生成结果是标准 QR Code，而不是示意图。
class QrCodeGenerator {
  const QrCodeGenerator._();

  static const int maxContentBytes = 78;
  static const List<int> _dataCodewords = [19, 34, 55, 80];
  static const List<int> _errorCodewords = [7, 10, 15, 20];
  static const List<int> _formatBitsL = [
    0x77C4,
    0x72F3,
    0x7DAA,
    0x789D,
    0x662F,
    0x6318,
    0x6C41,
    0x6976,
  ];

  static QrCodeMatrix encodeText(String content) {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('二维码内容不能为空');
    }
    final data = utf8.encode(normalized);
    if (data.length > maxContentBytes) {
      throw ArgumentError('二维码内容过长，请控制在 78 字节以内');
    }
    final version = _versionForLength(data.length);
    final size = 17 + version * 4;
    final codewords = _buildCodewords(version, data);
    final best = _buildBestMatrix(version, size, codewords);
    return QrCodeMatrix(version: version, modules: best);
  }

  static Uint8List renderPng(
    QrCodeMatrix matrix, {
    int scale = 12,
    int quietZone = 4,
  }) {
    if (scale < 2 || scale > 64) {
      throw ArgumentError('二维码缩放必须在 2 到 64 之间');
    }
    if (quietZone < 1 || quietZone > 16) {
      throw ArgumentError('二维码留白必须在 1 到 16 之间');
    }
    final moduleSize = matrix.size + quietZone * 2;
    final pixelSize = moduleSize * scale;
    final rgba = Uint8List(pixelSize * pixelSize * 4);
    for (var y = 0; y < pixelSize; y++) {
      for (var x = 0; x < pixelSize; x++) {
        final moduleX = x ~/ scale - quietZone;
        final moduleY = y ~/ scale - quietZone;
        final isDark =
            moduleX >= 0 &&
            moduleY >= 0 &&
            moduleX < matrix.size &&
            moduleY < matrix.size &&
            matrix.modules[moduleY][moduleX];
        final offset = (y * pixelSize + x) * 4;
        final color = isDark ? 0 : 255;
        rgba[offset] = color;
        rgba[offset + 1] = color;
        rgba[offset + 2] = color;
        rgba[offset + 3] = 255;
      }
    }
    return SimplePngEncoder.encodeRgba(
      width: pixelSize,
      height: pixelSize,
      rgba: rgba,
    );
  }

  static int _versionForLength(int length) {
    for (var version = 1; version <= _dataCodewords.length; version++) {
      if (length <= _byteCapacity(version)) {
        return version;
      }
    }
    throw ArgumentError('二维码内容过长，请控制在 78 字节以内');
  }

  static int _byteCapacity(int version) {
    final bitCapacity = _dataCodewords[version - 1] * 8;
    return (bitCapacity - 4 - 8) ~/ 8;
  }

  static List<int> _buildCodewords(int version, List<int> data) {
    final dataCapacity = _dataCodewords[version - 1];
    final bits = <int>[];
    _appendBits(bits, 0x4, 4);
    _appendBits(bits, data.length, 8);
    for (final byte in data) {
      _appendBits(bits, byte, 8);
    }
    final capacityBits = dataCapacity * 8;
    final terminator = (capacityBits - bits.length).clamp(0, 4);
    _appendBits(bits, 0, terminator);
    while (bits.length % 8 != 0) {
      bits.add(0);
    }
    final dataCodewords = <int>[];
    for (var i = 0; i < bits.length; i += 8) {
      var value = 0;
      for (var j = 0; j < 8; j++) {
        value = (value << 1) | bits[i + j];
      }
      dataCodewords.add(value);
    }
    var pad = 0;
    while (dataCodewords.length < dataCapacity) {
      dataCodewords.add(pad.isEven ? 0xEC : 0x11);
      pad++;
    }
    return [
      ...dataCodewords,
      ..._reedSolomon(dataCodewords, _errorCodewords[version - 1]),
    ];
  }

  static void _appendBits(List<int> bits, int value, int count) {
    for (var i = count - 1; i >= 0; i--) {
      bits.add((value >>> i) & 1);
    }
  }

  static List<List<bool>> _buildBestMatrix(
    int version,
    int size,
    List<int> codewords,
  ) {
    List<List<bool>>? best;
    var bestPenalty = 1 << 30;
    for (var mask = 0; mask < 8; mask++) {
      final reserved = List.generate(size, (_) => List.filled(size, false));
      final modules = List.generate(size, (_) => List.filled(size, false));
      _drawFunctionPatterns(modules, reserved, version);
      _drawData(modules, reserved, codewords, mask);
      _drawFormatBits(modules, reserved, mask);
      final penalty = _penalty(modules);
      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        best = modules;
      }
    }
    return best!;
  }

  static void _drawFunctionPatterns(
    List<List<bool>> modules,
    List<List<bool>> reserved,
    int version,
  ) {
    final size = modules.length;
    _drawFinder(modules, reserved, 0, 0);
    _drawFinder(modules, reserved, size - 7, 0);
    _drawFinder(modules, reserved, 0, size - 7);
    for (var i = 8; i < size - 8; i++) {
      final value = i.isEven;
      modules[6][i] = value;
      modules[i][6] = value;
      reserved[6][i] = true;
      reserved[i][6] = true;
    }
    if (version >= 2) {
      final center = version == 2
          ? 18
          : version == 3
          ? 22
          : 26;
      _drawAlignment(modules, reserved, center, center);
    }
    modules[size - 8][8] = true;
    reserved[size - 8][8] = true;
    for (var i = 0; i < 9; i++) {
      if (i != 6) {
        reserved[8][i] = true;
        reserved[i][8] = true;
      }
    }
    for (var i = 0; i < 8; i++) {
      reserved[8][size - 1 - i] = true;
      reserved[size - 1 - i][8] = true;
    }
  }

  static void _drawFinder(
    List<List<bool>> modules,
    List<List<bool>> reserved,
    int left,
    int top,
  ) {
    final size = modules.length;
    for (var y = -1; y <= 7; y++) {
      for (var x = -1; x <= 7; x++) {
        final px = left + x;
        final py = top + y;
        if (px < 0 || py < 0 || px >= size || py >= size) {
          continue;
        }
        final inFinder = x >= 0 && y >= 0 && x < 7 && y < 7;
        modules[py][px] =
            inFinder &&
            (x == 0 ||
                y == 0 ||
                x == 6 ||
                y == 6 ||
                (x >= 2 && x <= 4 && y >= 2 && y <= 4));
        reserved[py][px] = true;
      }
    }
  }

  static void _drawAlignment(
    List<List<bool>> modules,
    List<List<bool>> reserved,
    int centerX,
    int centerY,
  ) {
    for (var y = -2; y <= 2; y++) {
      for (var x = -2; x <= 2; x++) {
        final px = centerX + x;
        final py = centerY + y;
        modules[py][px] = x.abs() == 2 || y.abs() == 2 || (x == 0 && y == 0);
        reserved[py][px] = true;
      }
    }
  }

  static void _drawData(
    List<List<bool>> modules,
    List<List<bool>> reserved,
    List<int> codewords,
    int mask,
  ) {
    final bits = <int>[];
    for (final codeword in codewords) {
      _appendBits(bits, codeword, 8);
    }
    final size = modules.length;
    var bitIndex = 0;
    var upward = true;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) {
        right--;
      }
      for (var vertical = 0; vertical < size; vertical++) {
        final y = upward ? size - 1 - vertical : vertical;
        for (var column = 0; column < 2; column++) {
          final x = right - column;
          if (reserved[y][x]) {
            continue;
          }
          var value = bitIndex < bits.length && bits[bitIndex] == 1;
          if (_mask(mask, x, y)) {
            value = !value;
          }
          modules[y][x] = value;
          bitIndex++;
        }
      }
      upward = !upward;
    }
  }

  static void _drawFormatBits(
    List<List<bool>> modules,
    List<List<bool>> reserved,
    int mask,
  ) {
    final size = modules.length;
    final bits = _formatBitsL[mask];
    for (var i = 0; i < 15; i++) {
      final value = ((bits >>> i) & 1) == 1;
      final first = _formatCoordinateA(i);
      final second = _formatCoordinateB(i, size);
      modules[first.$2][first.$1] = value;
      modules[second.$2][second.$1] = value;
      reserved[first.$2][first.$1] = true;
      reserved[second.$2][second.$1] = true;
    }
  }

  static (int, int) _formatCoordinateA(int index) {
    return switch (index) {
      0 => (8, 0),
      1 => (8, 1),
      2 => (8, 2),
      3 => (8, 3),
      4 => (8, 4),
      5 => (8, 5),
      6 => (8, 7),
      7 => (8, 8),
      8 => (7, 8),
      9 => (5, 8),
      10 => (4, 8),
      11 => (3, 8),
      12 => (2, 8),
      13 => (1, 8),
      _ => (0, 8),
    };
  }

  static (int, int) _formatCoordinateB(int index, int size) {
    if (index < 8) {
      return (size - 1 - index, 8);
    }
    return (8, size - 15 + index);
  }

  static bool _mask(int mask, int x, int y) {
    return switch (mask) {
      0 => (x + y).isEven,
      1 => y.isEven,
      2 => x % 3 == 0,
      3 => (x + y) % 3 == 0,
      4 => ((y ~/ 2) + (x ~/ 3)).isEven,
      5 => ((x * y) % 2 + (x * y) % 3) == 0,
      6 => (((x * y) % 2 + (x * y) % 3) % 2) == 0,
      _ => (((x + y) % 2 + (x * y) % 3) % 2) == 0,
    };
  }

  static int _penalty(List<List<bool>> modules) {
    final size = modules.length;
    var penalty = 0;
    for (var y = 0; y < size; y++) {
      var runColor = modules[y][0];
      var runLength = 1;
      for (var x = 1; x < size; x++) {
        if (modules[y][x] == runColor) {
          runLength++;
        } else {
          if (runLength >= 5) {
            penalty += 3 + runLength - 5;
          }
          runColor = modules[y][x];
          runLength = 1;
        }
      }
      if (runLength >= 5) {
        penalty += 3 + runLength - 5;
      }
    }
    for (var x = 0; x < size; x++) {
      var runColor = modules[0][x];
      var runLength = 1;
      for (var y = 1; y < size; y++) {
        if (modules[y][x] == runColor) {
          runLength++;
        } else {
          if (runLength >= 5) {
            penalty += 3 + runLength - 5;
          }
          runColor = modules[y][x];
          runLength = 1;
        }
      }
      if (runLength >= 5) {
        penalty += 3 + runLength - 5;
      }
    }
    for (var y = 0; y < size - 1; y++) {
      for (var x = 0; x < size - 1; x++) {
        final color = modules[y][x];
        if (modules[y][x + 1] == color &&
            modules[y + 1][x] == color &&
            modules[y + 1][x + 1] == color) {
          penalty += 3;
        }
      }
    }
    final dark = modules.expand((row) => row).where((value) => value).length;
    final percent = dark * 100 ~/ (size * size);
    penalty += ((percent - 50).abs() ~/ 5) * 10;
    return penalty;
  }

  static List<int> _reedSolomon(List<int> data, int degree) {
    final generator = _generatorPolynomial(degree);
    final result = List<int>.filled(degree, 0, growable: true);
    for (final value in data) {
      final factor = value ^ result.removeAt(0);
      result.add(0);
      for (var i = 0; i < degree; i++) {
        result[i] ^= _gfMultiply(generator[i], factor);
      }
    }
    return result;
  }

  static List<int> _generatorPolynomial(int degree) {
    var poly = <int>[1];
    for (var i = 0; i < degree; i++) {
      final next = List<int>.filled(poly.length + 1, 0);
      for (var j = 0; j < poly.length; j++) {
        next[j] ^= _gfMultiply(poly[j], _gfPow(2, i));
        next[j + 1] ^= poly[j];
      }
      poly = next;
    }
    return poly.skip(1).toList(growable: false);
  }

  static int _gfPow(int value, int power) {
    var result = 1;
    for (var i = 0; i < power; i++) {
      result = _gfMultiply(result, value);
    }
    return result;
  }

  static int _gfMultiply(int a, int b) {
    var x = a;
    var y = b;
    var result = 0;
    while (y > 0) {
      if ((y & 1) != 0) {
        result ^= x;
      }
      y >>>= 1;
      x <<= 1;
      if ((x & 0x100) != 0) {
        x ^= 0x11D;
      }
    }
    return result & 0xFF;
  }
}
