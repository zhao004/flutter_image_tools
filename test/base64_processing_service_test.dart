import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_tools/app/services/base64_processing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Base64ProcessingService', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'image_tools_base64_test_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('在后台完成编码和 Data URI 解码往返', () async {
      final sourceBytes = List<int>.generate(4096, (index) => index % 251);
      final source = File('${temporaryDirectory.path}/source.bin');
      await source.writeAsBytes(sourceBytes, flush: true);

      final encoded = await Base64ProcessingService.encodeFile(
        path: source.path,
        maxInputBytes: 8192,
      );
      final decoded = await Base64ProcessingService.decodeToImage(
        rawText: 'data:image/png;base64,${encoded.text}',
        outputDirectory: '${temporaryDirectory.path}/decoded',
        maxBase64Chars: 16384,
      );

      expect(encoded.sourceSizeBytes, sourceBytes.length);
      expect(base64Decode(encoded.text), sourceBytes);
      expect(await File(decoded.outputPath).readAsBytes(), sourceBytes);
      expect(decoded.mimeType, 'image/png');
      expect(decoded.base64Length, encoded.text.length);
    });

    test('超过文件大小上限时拒绝编码', () async {
      final source = File('${temporaryDirectory.path}/large.bin');
      await source.writeAsBytes(List<int>.filled(32, 1), flush: true);

      expect(
        () => Base64ProcessingService.encodeFile(
          path: source.path,
          maxInputBytes: 16,
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('拒绝缺少 base64 标记的 Data URI', () {
      expect(
        () => Base64ProcessingService.decodeToImage(
          rawText: 'data:image/png,AAAA',
          outputDirectory: temporaryDirectory.path,
          maxBase64Chars: 1024,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('长文本预览仅保留首尾固定长度', () {
      final prefix = List<String>.filled(100, 'A').join();
      final suffix = List<String>.filled(100, 'B').join();
      final preview = Base64ProcessingService.buildPreview(
        '$prefix$suffix',
        edgeLength: 12,
      );

      expect(preview, startsWith(List<String>.filled(12, 'A').join()));
      expect(preview, endsWith(List<String>.filled(12, 'B').join()));
      expect(preview.length, lessThan(40));
    });
  });
}
