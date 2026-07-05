import 'package:flutter_image_tools/app/core/models/gif_image_file.dart';
import 'package:flutter_image_tools/app/core/models/local_image_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GifImageFile', () {
    test('解析 GIF 生成结果并保留帧参数', () {
      // 平台通道返回导出路径和编码信息，模型负责冻结源图片列表并兜底帧数。
      const first = LocalImageFile(
        path: '/tmp/first.png',
        name: 'first.png',
        sizeBytes: 1024,
        mimeType: 'image/png',
        width: 320,
        height: 240,
      );
      const second = LocalImageFile(
        path: '/tmp/second.jpg',
        name: 'second.jpg',
        sizeBytes: 2048,
        mimeType: 'image/jpeg',
        width: 320,
        height: 240,
      );

      final gif = GifImageFile.fromMap(
        sources: const [first, second],
        delayMs: 300,
        map: const <Object?, Object?>{
          'outputPath': '/tmp/images.gif',
          'outputSizeBytes': 4096,
          'frameCount': 2,
          'delayMs': 120,
          'width': 320,
          'height': 240,
        },
      );

      expect(gif.sources, const [first, second]);
      expect(gif.outputPath, '/tmp/images.gif');
      expect(gif.outputSizeBytes, 4096);
      expect(gif.frameCount, 2);
      expect(gif.delayMs, 120);
      expect(gif.width, 320);
      expect(gif.height, 240);
      expect(gif.hasValidDimensions, isTrue);
      expect(() => gif.sources.add(first), throwsUnsupportedError);
    });

    test('通道缺少帧数和延迟时使用输入参数兜底', () {
      const first = LocalImageFile(
        path: '/tmp/first.png',
        name: 'first.png',
        sizeBytes: 1024,
        mimeType: 'image/png',
        width: 320,
        height: 240,
      );
      const second = LocalImageFile(
        path: '/tmp/second.png',
        name: 'second.png',
        sizeBytes: 2048,
        mimeType: 'image/png',
        width: 320,
        height: 240,
      );

      final gif = GifImageFile.fromMap(
        sources: const [first, second],
        delayMs: 500,
        map: const <Object?, Object?>{'outputPath': '/tmp/fallback.gif'},
      );

      expect(gif.frameCount, 2);
      expect(gif.delayMs, 500);
      expect(gif.hasValidDimensions, isFalse);
    });
  });
}
