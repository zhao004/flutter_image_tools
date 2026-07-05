import 'package:flutter_image_tools/app/core/models/local_image_file.dart';
import 'package:flutter_image_tools/app/core/models/pdf_document_file.dart';
import 'package:flutter_image_tools/app/core/models/pdf_image_file.dart';
import 'package:flutter_image_tools/app/core/models/pdf_page_image_file.dart';
import 'package:flutter_image_tools/app/core/models/pdf_pages_image_export.dart';
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

  group('PdfDocumentFile', () {
    test('解析 PDF 文件选择结果并使用安全默认值', () {
      final pdf = PdfDocumentFile.fromMap(const <Object?, Object?>{
        'path': '/tmp/source.pdf',
        'name': 'source.pdf',
        'sizeBytes': 4096,
      });

      expect(pdf.path, '/tmp/source.pdf');
      expect(pdf.name, 'source.pdf');
      expect(pdf.sizeBytes, 4096);
      expect(pdf.mimeType, 'application/pdf');
    });
  });

  group('PdfPageImageFile', () {
    test('解析 PDF 页面导出图片结果并保留页码信息', () {
      final image = PdfPageImageFile.fromMap(
        sourcePath: '/tmp/source.pdf',
        sourceName: 'source.pdf',
        requestedPageNumber: 2,
        map: const <Object?, Object?>{
          'outputPath': '/tmp/page_2.png',
          'outputSizeBytes': 8192,
          'pageNumber': 2,
          'pageCount': 5,
          'width': 1200,
          'height': 1600,
        },
      );

      expect(image.sourcePath, '/tmp/source.pdf');
      expect(image.sourceName, 'source.pdf');
      expect(image.outputPath, '/tmp/page_2.png');
      expect(image.outputSizeBytes, 8192);
      expect(image.pageNumber, 2);
      expect(image.pageCount, 5);
      expect(image.width, 1200);
      expect(image.height, 1600);
      expect(image.hasValidDimensions, isTrue);
    });

    test('通道缺少页码时使用请求页码兜底', () {
      final image = PdfPageImageFile.fromMap(
        sourcePath: '/tmp/source.pdf',
        sourceName: 'source.pdf',
        requestedPageNumber: 3,
        map: const <Object?, Object?>{'outputPath': '/tmp/page_3.png'},
      );

      expect(image.pageNumber, 3);
      expect(image.pageCount, 0);
      expect(image.hasValidDimensions, isFalse);
    });
  });

  group('PdfPagesImageExport', () {
    test('解析 PDF 全部页面导出结果并冻结路径列表', () {
      final export = PdfPagesImageExport.fromMap(
        sourcePath: '/tmp/source.pdf',
        sourceName: 'source.pdf',
        map: const <Object?, Object?>{
          'outputDirectory': '/tmp/pdf_pages',
          'outputPaths': [
            '/tmp/pdf_pages/page_1.png',
            '/tmp/pdf_pages/page_2.png',
          ],
          'totalOutputSizeBytes': 16384,
          'pageCount': 2,
        },
      );

      expect(export.sourcePath, '/tmp/source.pdf');
      expect(export.sourceName, 'source.pdf');
      expect(export.outputDirectory, '/tmp/pdf_pages');
      expect(export.outputPaths, hasLength(2));
      expect(export.totalOutputSizeBytes, 16384);
      expect(export.pageCount, 2);
      expect(export.isComplete, isTrue);
      expect(
        () => export.outputPaths.add('/tmp/other.png'),
        throwsUnsupportedError,
      );
    });

    test('缺少页数时使用输出路径数量兜底', () {
      final export = PdfPagesImageExport.fromMap(
        sourcePath: '/tmp/source.pdf',
        sourceName: 'source.pdf',
        map: const <Object?, Object?>{
          'outputDirectory': '/tmp/pdf_pages',
          'outputPaths': ['/tmp/pdf_pages/page_1.png'],
        },
      );

      expect(export.pageCount, 1);
      expect(export.isComplete, isTrue);
    });
  });
}
