import 'package:flutter_image_tools/app/core/models/filtered_image_file.dart';
import 'package:flutter_image_tools/app/core/models/local_image_file.dart';
import 'package:flutter_image_tools/app/services/local_image_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilteredImageFile', () {
    test('解析滤镜结果并保留平台返回类型', () {
      // 平台通道会返回实际导出路径和滤镜名，模型层只做安全兜底。
      const source = LocalImageFile(
        path: '/tmp/source.jpg',
        name: 'source.jpg',
        sizeBytes: 4096,
        mimeType: 'image/jpeg',
        width: 640,
        height: 480,
      );

      final filtered = FilteredImageFile.fromMap(
        source: source,
        filter: 'grayscale',
        map: const <Object?, Object?>{
          'outputPath': '/tmp/filtered.jpg',
          'outputSizeBytes': 2048,
          'filter': 'film',
        },
      );

      expect(filtered.source, source);
      expect(filtered.outputPath, '/tmp/filtered.jpg');
      expect(filtered.outputSizeBytes, 2048);
      expect(filtered.filter, 'film');
    });

    test('通道缺少滤镜类型时使用请求参数兜底', () {
      const source = LocalImageFile(
        path: '/tmp/source.jpg',
        name: 'source.jpg',
        sizeBytes: 4096,
        mimeType: 'image/jpeg',
        width: 640,
        height: 480,
      );

      final filtered = FilteredImageFile.fromMap(
        source: source,
        filter: 'hdr',
        map: const <Object?, Object?>{'outputPath': '/tmp/hdr.jpg'},
      );

      expect(filtered.filter, 'hdr');
      expect(filtered.outputSizeBytes, 0);
    });
  });

  group('LocalImageChannel', () {
    test('滤镜白名单包含扩展滤镜', () {
      expect(LocalImageChannel.supportedFilters, contains('hdr'));
      expect(LocalImageChannel.supportedFilters, contains('film'));
      expect(LocalImageChannel.supportedFilters, contains('sharpen'));
      expect(LocalImageChannel.supportedFilters, contains('soften'));
    });
  });
}
