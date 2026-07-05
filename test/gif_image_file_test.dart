import 'package:flutter_image_tools/app/core/models/compressed_gif_file.dart';
import 'package:flutter_image_tools/app/core/models/gif_frames_export.dart';
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

  group('GifFramesExport', () {
    test('解析 GIF 拆帧结果并冻结输出路径', () {
      const source = LocalImageFile(
        path: '/tmp/source.gif',
        name: 'source.gif',
        sizeBytes: 4096,
        mimeType: 'image/gif',
        width: 320,
        height: 240,
      );

      final export = GifFramesExport.fromMap(
        source: source,
        frameStepMs: 200,
        map: const <Object?, Object?>{
          'outputDirectory': '/tmp/gif_frames',
          'outputPaths': [
            '/tmp/gif_frames/frame_1.png',
            '/tmp/gif_frames/frame_2.png',
          ],
          'totalOutputSizeBytes': 8192,
          'frameCount': 2,
          'durationMs': 400,
          'frameStepMs': 200,
          'width': 320,
          'height': 240,
        },
      );

      expect(export.source, source);
      expect(export.outputDirectory, '/tmp/gif_frames');
      expect(export.outputPaths, hasLength(2));
      expect(export.totalOutputSizeBytes, 8192);
      expect(export.frameCount, 2);
      expect(export.durationMs, 400);
      expect(export.frameStepMs, 200);
      expect(export.isComplete, isTrue);
      expect(
        () => export.outputPaths.add('/tmp/gif_frames/frame_3.png'),
        throwsUnsupportedError,
      );
    });

    test('缺少帧数时使用输出路径数量兜底', () {
      const source = LocalImageFile(
        path: '/tmp/source.gif',
        name: 'source.gif',
        sizeBytes: 4096,
        mimeType: 'image/gif',
        width: 320,
        height: 240,
      );

      final export = GifFramesExport.fromMap(
        source: source,
        frameStepMs: 250,
        map: const <Object?, Object?>{
          'outputDirectory': '/tmp/gif_frames',
          'outputPaths': ['/tmp/gif_frames/frame_1.png'],
          'width': 320,
          'height': 240,
        },
      );

      expect(export.frameCount, 1);
      expect(export.frameStepMs, 250);
      expect(export.isComplete, isTrue);
    });
  });

  group('CompressedGifFile', () {
    test('解析 GIF 压缩结果并计算节省比例', () {
      const source = LocalImageFile(
        path: '/tmp/source.gif',
        name: 'source.gif',
        sizeBytes: 10000,
        mimeType: 'image/gif',
        width: 640,
        height: 480,
      );

      final compressed = CompressedGifFile.fromMap(
        source: source,
        frameStepMs: 250,
        scalePercent: 60,
        map: const <Object?, Object?>{
          'outputPath': '/tmp/compressed.gif',
          'outputSizeBytes': 4000,
          'originalSizeBytes': 10000,
          'frameCount': 4,
          'frameStepMs': 250,
          'scalePercent': 60,
          'width': 384,
          'height': 288,
        },
      );

      expect(compressed.source, source);
      expect(compressed.outputPath, '/tmp/compressed.gif');
      expect(compressed.outputSizeBytes, 4000);
      expect(compressed.originalSizeBytes, 10000);
      expect(compressed.frameCount, 4);
      expect(compressed.frameStepMs, 250);
      expect(compressed.scalePercent, 60);
      expect(compressed.width, 384);
      expect(compressed.height, 288);
      expect(compressed.savedSizeBytes, 6000);
      expect(compressed.savedRatio, 0.6);
      expect(compressed.hasValidOutput, isTrue);
    });

    test('缺少原始大小时使用源文件大小兜底', () {
      const source = LocalImageFile(
        path: '/tmp/source.gif',
        name: 'source.gif',
        sizeBytes: 5000,
        mimeType: 'image/gif',
        width: 320,
        height: 240,
      );

      final compressed = CompressedGifFile.fromMap(
        source: source,
        frameStepMs: 300,
        scalePercent: 50,
        map: const <Object?, Object?>{
          'outputPath': '/tmp/compressed.gif',
          'outputSizeBytes': 6000,
          'frameCount': 2,
          'width': 160,
          'height': 120,
        },
      );

      expect(compressed.originalSizeBytes, 5000);
      expect(compressed.savedSizeBytes, 0);
      expect(compressed.savedRatio, 0);
      expect(compressed.frameStepMs, 300);
      expect(compressed.scalePercent, 50);
    });
  });
}
