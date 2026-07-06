import 'package:flutter_image_tools/app/models/exif_info.dart';
import 'package:flutter_image_tools/app/models/local_image_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExifInfo', () {
    test('解析并过滤空 EXIF 字段', () {
      // 空键和值来自不同 Android ROM 的异常返回，模型层统一过滤，避免页面显示无意义条目。
      const source = LocalImageFile(
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        sizeBytes: 1024,
        mimeType: 'image/jpeg',
        width: 800,
        height: 600,
      );

      final info = ExifInfo.fromMap(
        source: source,
        map: <Object?, Object?>{
          'attributes': <Object?, Object?>{
            '拍摄时间': '2026:07:06 12:00:00',
            'GPS': ' ',
            '': 'N 30/1',
            'ISO': '100',
          },
        },
      );

      expect(info.source, same(source));
      expect(info.hasExif, isTrue);
      expect(info.attributes, <String, String>{
        '拍摄时间': '2026:07:06 12:00:00',
        'ISO': '100',
      });
    });

    test('缺少属性时返回空 EXIF 状态', () {
      // 没有 EXIF 的图片仍然是合法结果，页面据此展示“未读取到 EXIF”。
      const source = LocalImageFile(
        path: '/tmp/clean.jpg',
        name: 'clean.jpg',
        sizeBytes: 2048,
        mimeType: 'image/jpeg',
        width: 1024,
        height: 768,
      );

      final info = ExifInfo.fromMap(
        source: source,
        map: const <Object?, Object?>{},
      );

      expect(info.hasExif, isFalse);
      expect(info.attributes, isEmpty);
    });
  });
}
