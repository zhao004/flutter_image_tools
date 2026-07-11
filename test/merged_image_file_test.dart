import 'package:flutter_image_tools/app/models/local_image_file.dart';
import 'package:flutter_image_tools/app/models/merged_image_file.dart';
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
        mode: 'horizontal',
        backgroundColor: '#FFFFFF',
        borderWidth: 0,
        cornerRadius: 0,
        scaleMode: 'same_height',
        map: const <Object?, Object?>{
          'outputPath': '/tmp/merged.jpg',
          'outputSizeBytes': 8192,
          'width': 1280,
          'height': 960,
          'mode': 'horizontal',
          'backgroundColor': '#333333',
          'borderWidth': 4,
          'cornerRadius': 24,
          'scaleMode': 'same_height',
        },
      );

      expect(merged.sources, const [source, source]);
      expect(merged.outputPath, '/tmp/merged.jpg');
      expect(merged.outputSizeBytes, 8192);
      expect(merged.width, 1280);
      expect(merged.height, 960);
      expect(merged.mode, 'horizontal');
      expect(merged.backgroundColor, '#333333');
      expect(merged.borderWidth, 4);
      expect(merged.cornerRadius, 24);
      expect(merged.scaleMode, 'same_height');
      expect(() => merged.sources.add(source), throwsUnsupportedError);
    });

    test('通道缺少背景、边框、圆角和缩放模式时使用请求参数兜底', () {
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
        cornerRadius: 12,
        scaleMode: 'same_width',
        map: const <Object?, Object?>{'outputPath': '/tmp/merged.jpg'},
      );

      expect(merged.mode, 'horizontal');
      expect(merged.backgroundColor, '#F2F2F2');
      expect(merged.borderWidth, 2);
      expect(merged.cornerRadius, 12);
      expect(merged.scaleMode, 'same_width');
    });

    test('纵向模式保留平台回传模式', () {
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
        mode: 'vertical',
        backgroundColor: '#FFFFFF',
        borderWidth: 0,
        cornerRadius: 0,
        scaleMode: 'same_width',
        map: const <Object?, Object?>{
          'outputPath': '/tmp/vertical.jpg',
          'mode': 'vertical',
          'scaleMode': 'same_width',
        },
      );

      expect(merged.outputPath, '/tmp/vertical.jpg');
      expect(merged.mode, 'vertical');
      expect(merged.scaleMode, 'same_width');
    });
  });
}
