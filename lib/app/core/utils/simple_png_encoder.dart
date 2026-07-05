import 'dart:convert';
import 'dart:typed_data';

/// 极简 PNG 编码器，只生成 8-bit RGBA、无交错图片。
///
/// 设计意图：二维码导出只需要黑白像素，使用未压缩 deflate 块可避免引入
/// 额外依赖；代价是文件略大，但二维码图片体积仍很小，换取实现可控和离线。
class SimplePngEncoder {
  const SimplePngEncoder._();

  static Uint8List encodeRgba({
    required int width,
    required int height,
    required Uint8List rgba,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('PNG 宽高必须大于 0');
    }
    final expectedLength = width * height * 4;
    if (rgba.length != expectedLength) {
      throw ArgumentError('RGBA 像素长度不匹配');
    }

    final scanlines = BytesBuilder();
    var offset = 0;
    for (var y = 0; y < height; y++) {
      scanlines.addByte(0);
      scanlines.add(rgba.sublist(offset, offset + width * 4));
      offset += width * 4;
    }

    final output = BytesBuilder();
    output.add(const <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    output.add(_chunk('IHDR', _ihdr(width, height)));
    output.add(_chunk('IDAT', _zlibStore(scanlines.toBytes())));
    output.add(_chunk('IEND', Uint8List(0)));
    return output.toBytes();
  }

  static Uint8List _ihdr(int width, int height) {
    final bytes = ByteData(13);
    bytes.setUint32(0, width);
    bytes.setUint32(4, height);
    bytes.setUint8(8, 8);
    bytes.setUint8(9, 6);
    bytes.setUint8(10, 0);
    bytes.setUint8(11, 0);
    bytes.setUint8(12, 0);
    return bytes.buffer.asUint8List();
  }

  static Uint8List _chunk(String type, Uint8List data) {
    final typeBytes = ascii.encode(type);
    final bytes = BytesBuilder();
    final length = ByteData(4)..setUint32(0, data.length);
    bytes.add(length.buffer.asUint8List());
    bytes.add(typeBytes);
    bytes.add(data);
    final crcInput = BytesBuilder()
      ..add(typeBytes)
      ..add(data);
    final crc = ByteData(4)..setUint32(0, _crc32(crcInput.toBytes()));
    bytes.add(crc.buffer.asUint8List());
    return bytes.toBytes();
  }

  static Uint8List _zlibStore(Uint8List data) {
    final bytes = BytesBuilder();
    bytes.add(const <int>[0x78, 0x01]);
    var offset = 0;
    while (offset < data.length) {
      final remaining = data.length - offset;
      final blockLength = remaining > 65535 ? 65535 : remaining;
      final isFinal = offset + blockLength >= data.length;
      bytes.addByte(isFinal ? 1 : 0);
      bytes.addByte(blockLength & 0xFF);
      bytes.addByte((blockLength >> 8) & 0xFF);
      final inverse = 0xFFFF - blockLength;
      bytes.addByte(inverse & 0xFF);
      bytes.addByte((inverse >> 8) & 0xFF);
      bytes.add(data.sublist(offset, offset + blockLength));
      offset += blockLength;
    }
    final adler = ByteData(4)..setUint32(0, _adler32(data));
    bytes.add(adler.buffer.asUint8List());
    return bytes.toBytes();
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? 0xEDB88320 ^ (crc >>> 1) : crc >>> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static int _adler32(List<int> bytes) {
    const mod = 65521;
    var a = 1;
    var b = 0;
    for (final byte in bytes) {
      a = (a + byte) % mod;
      b = (b + a) % mod;
    }
    return ((b << 16) | a) & 0xFFFFFFFF;
  }
}
