import 'package:flutter_image_tools/app/core/models/local_image_file.dart';
import 'package:flutter_image_tools/app/core/models/merged_image_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergedImageFile', () {
    test('解析拼接结果并保留背景颜色', () {
      // 拼接背景色由页面传入并由平台回传，模型层负责兜底展示字段。
      const source = LocalImageFile(
        path: '/tmp/source.jpg',
        name: 'source.jpg',
        sizeBytes: 4096,
        mimeType: 'image/jpeg',
        width: 640,
        height: 480,
      );

      final merged = MergedImageFile.fromMap(
        sources: const [source, source],
        mode: 'grid',
        backgroundColor: '#FFFFFF',
        borderWidth: 0,
        borderColor: '#000000',
        map: const <Object?, Object?>{
          'outputPath': '/tmp/merged.jpg',
          'outputSizeBytes': 8192,
          'width': 1280,
          'height': 960,
          'mode': 'grid',
          'backgroundColor': '#333333',
          'borderWidth': 4,
          'borderColor': '#FFFFFF',
        },
      );

      expect(merged.sources, const [source, source]);
      expect(merged.outputPath, '/tmp/merged.jpg');
      expect(merged.outputSizeBytes, 8192);
      expect(merged.width, 1280);
      expect(merged.height, 960);
      expect(merged.mode, 'grid');
      expect(merged.backgroundColor, '#333333');
      expect(merged.borderWidth, 4);
      expect(merged.borderColor, '#FFFFFF');
      expect(() => merged.sources.add(source), throwsUnsupportedError);
    });

    test('通道缺少背景和边框时使用请求参数兜底', () {
      const source = LocalImageFile(
        path: '/tmp/source.jpg',
        name: 'source.jpg',
        sizeBytes: 4096,
        mimeType: 'image/jpeg',
        width: 640,
        height: 480,
      );

      final merged = MergedImageFile.fromMap(
        sources: const [source, source],
        mode: 'horizontal',
        backgroundColor: '#F2F2F2',
        borderWidth: 2,
        borderColor: '#808080',
        map: const <Object?, Object?>{'outputPath': '/tmp/merged.jpg'},
      );

      expect(merged.mode, 'horizontal');
      expect(merged.backgroundColor, '#F2F2F2');
      expect(merged.borderWidth, 2);
      expect(merged.borderColor, '#808080');
    });
  });
}
