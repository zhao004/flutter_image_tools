import 'package:flutter_image_tools/app/core/models/local_image_file.dart';
import 'package:flutter_image_tools/app/core/models/pdf_image_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfImageFile', () {
    test('解析图片转 PDF 结果并保留页面参数', () {
      // PDF 结果来自平台通道，模型层负责兜底页面参数并冻结源图片列表。
      const source = LocalImageFile(
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        sizeBytes: 4096,
        mimeType: 'image/jpeg',
        width: 800,
        height: 600,
      );

      final pdf = PdfImageFile.fromMap(
        sources: const [source],
        pageSize: 'a4',
        orientation: 'portrait',
        map: const <Object?, Object?>{
          'outputPath': '/tmp/images.pdf',
          'outputSizeBytes': 8192,
          'pageSize': 'a3',
          'orientation': 'landscape',
          'pageCount': 1,
        },
      );

      expect(pdf.sources, const [source]);
      expect(pdf.outputPath, '/tmp/images.pdf');
      expect(pdf.outputSizeBytes, 8192);
      expect(pdf.pageSize, 'a3');
      expect(pdf.orientation, 'landscape');
      expect(pdf.pageCount, 1);
      expect(() => pdf.sources.add(source), throwsUnsupportedError);
    });

    test('通道缺少页数时使用源图片数量兜底', () {
      // 老版本平台返回可能缺少 pageCount，Dart 模型用输入数量保证结果展示稳定。
      const first = LocalImageFile(
        path: '/tmp/first.png',
        name: 'first.png',
        sizeBytes: 1024,
        mimeType: 'image/png',
        width: 300,
        height: 300,
      );
      const second = LocalImageFile(
        path: '/tmp/second.png',
        name: 'second.png',
        sizeBytes: 2048,
        mimeType: 'image/png',
        width: 400,
        height: 400,
      );

      final pdf = PdfImageFile.fromMap(
        sources: const [first, second],
        pageSize: 'a4',
        orientation: 'portrait',
        map: const <Object?, Object?>{'outputPath': '/tmp/fallback.pdf'},
      );

      expect(pdf.pageCount, 2);
      expect(pdf.pageSize, 'a4');
      expect(pdf.orientation, 'portrait');
    });
  });
}
