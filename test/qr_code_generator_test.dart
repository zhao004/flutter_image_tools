import 'package:flutter_image_tools/app/models/barcode_scan_result.dart';
import 'package:flutter_image_tools/app/models/barcode_image_file.dart';
import 'package:flutter_image_tools/app/models/local_image_file.dart';
import 'package:flutter_image_tools/app/models/qr_code_image_file.dart';
import 'package:flutter_image_tools/app/utils/barcode_generator.dart';
import 'package:flutter_image_tools/app/utils/qr_code_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrCodeGenerator', () {
    test('生成短文本二维码矩阵和 PNG 头', () {
      final matrix = QrCodeGenerator.encodeText('hello');
      final png = QrCodeGenerator.renderPng(matrix, scale: 4);

      expect(matrix.version, 1);
      expect(matrix.size, 21);
      expect(matrix.modules, hasLength(21));
      expect(matrix.modules.first, hasLength(21));
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(png.length, greaterThan(100));
    });

    test('内容为空或过长时抛出参数错误', () {
      expect(() => QrCodeGenerator.encodeText('   '), throwsArgumentError);
      expect(
        () => QrCodeGenerator.encodeText(
          'a' * (QrCodeGenerator.maxContentBytes + 1),
        ),
        throwsArgumentError,
      );
    });

    test('Version 1-L 使用标准七阶 Reed-Solomon 生成多项式', () {
      expect(QrCodeGenerator.generatorPolynomialForTesting(7), [
        127,
        122,
        154,
        164,
        11,
        68,
        117,
      ]);
    });
  });

  group('BarcodeGenerator', () {
    test('生成 Code 128 条形码 PNG', () {
      final result = BarcodeGenerator.renderCode128Png(
        'ABC-123',
        moduleWidth: 2,
        height: 100,
      );

      expect(result.pixelWidth, greaterThan(120));
      expect(result.pixelHeight, 100);
      expect(result.png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(result.png.length, greaterThan(100));
    });

    test('条形码内容非法时抛出参数错误', () {
      expect(() => BarcodeGenerator.renderCode128Png(''), throwsArgumentError);
      expect(
        () => BarcodeGenerator.renderCode128Png('中文'),
        throwsArgumentError,
      );
      expect(
        () => BarcodeGenerator.renderCode128Png(
          'A' * (BarcodeGenerator.maxContentLength + 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('QrCodeImageFile', () {
    test('校验导出结果必要字段', () {
      const file = QrCodeImageFile(
        content: 'hello',
        outputPath: '/tmp/qrcode.png',
        outputSizeBytes: 1024,
        version: 1,
        moduleCount: 21,
        pixelSize: 348,
      );

      expect(file.hasValidOutput, isTrue);
    });
  });

  group('BarcodeImageFile', () {
    test('校验条形码导出结果必要字段', () {
      const file = BarcodeImageFile(
        content: 'ABC-123',
        outputPath: '/tmp/barcode.png',
        outputSizeBytes: 2048,
        format: 'CODE_128',
        pixelWidth: 420,
        pixelHeight: 160,
      );

      expect(file.hasValidOutput, isTrue);
    });
  });

  group('BarcodeScanResult', () {
    test('解析本地扫码结果并保留源图片', () {
      const source = LocalImageFile(
        path: '/tmp/code.png',
        name: 'code.png',
        sizeBytes: 2048,
        mimeType: 'image/png',
        width: 320,
        height: 320,
      );

      final result = BarcodeScanResult.fromMap(
        source: source,
        map: const <Object?, Object?>{
          'text': 'https://example.com',
          'format': 'QR_CODE',
          'rawBytesLength': 19,
        },
      );

      expect(result.source, source);
      expect(result.text, 'https://example.com');
      expect(result.format, 'QR_CODE');
      expect(result.rawBytesLength, 19);
      expect(result.hasText, isTrue);
    });

    test('缺少格式时使用 unknown 兜底', () {
      const source = LocalImageFile(
        path: '/tmp/code.png',
        name: 'code.png',
        sizeBytes: 2048,
        mimeType: 'image/png',
        width: 320,
        height: 320,
      );

      final result = BarcodeScanResult.fromMap(
        source: source,
        map: const <Object?, Object?>{},
      );

      expect(result.format, 'unknown');
      expect(result.hasText, isFalse);
    });
  });
}
