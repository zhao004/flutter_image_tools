import 'package:flutter_image_tools/app/core/models/annotated_image_file.dart';
import 'package:flutter_image_tools/app/core/models/local_image_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnnotatedImageFile', () {
    test('解析平台标注结果并保留模式兜底', () {
      // 平台通道可能省略 mode，模型层使用调用方参数兜底，保证历史展示稳定。
      const source = LocalImageFile(
        path: '/tmp/source.jpg',
        name: 'source.jpg',
        sizeBytes: 1024,
        mimeType: 'image/jpeg',
        width: 800,
        height: 600,
      );

      final result = AnnotatedImageFile.fromMap(
        source: source,
        mode: 'arrow',
        map: const <Object?, Object?>{
          'outputPath': '/tmp/annotated.jpg',
          'outputSizeBytes': 2048,
        },
      );

      expect(result.source, same(source));
      expect(result.outputPath, '/tmp/annotated.jpg');
      expect(result.outputSizeBytes, 2048);
      expect(result.mode, 'arrow');
    });
  });
}
