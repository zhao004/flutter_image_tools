import 'package:flutter_image_tools/app/core/models/qr_code_image_file.dart';
import 'package:flutter_image_tools/app/core/utils/qr_code_generator.dart';
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
}
