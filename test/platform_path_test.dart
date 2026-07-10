import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_image_tools/app/utils/platform_path.dart';

void main() {
  group('PlatformPath.join', () {
    test('Android 路径使用正斜杠且不产生反斜杠文件名', () {
      final result = PlatformPath.join(
        '/data/user/0/com.zhao.imagetoolkit/cache',
        'image_tools_gif',
        separator: '/',
      );

      expect(
        result,
        '/data/user/0/com.zhao.imagetoolkit/cache/image_tools_gif',
      );
      expect(result, isNot(contains(r'\')));
    });

    test('移除父子路径边界处重复分隔符', () {
      final result = PlatformPath.join(
        '/data/user/0/cache/',
        '/image_tools_grid',
        separator: '/',
      );

      expect(result, '/data/user/0/cache/image_tools_grid');
    });

    test('Unix 根目录不会产生双斜杠', () {
      final result = PlatformPath.join('/', 'image_tools_gif', separator: '/');

      expect(result, '/image_tools_gif');
    });

    test('Windows 路径保留反斜杠语义', () {
      final result = PlatformPath.join(
        r'C:\Temp\',
        r'\image_tools_gif',
        separator: r'\',
      );

      expect(result, r'C:\Temp\image_tools_gif');
    });

    test('空路径和非法分隔符会立即失败', () {
      expect(
        () => PlatformPath.join('', 'output.gif', separator: '/'),
        throwsArgumentError,
      );
      expect(
        () => PlatformPath.join('/tmp', '/', separator: '/'),
        throwsArgumentError,
      );
      expect(
        () => PlatformPath.join('/tmp', 'output.gif', separator: ':'),
        throwsArgumentError,
      );
    });
  });
}
