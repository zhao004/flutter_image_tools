import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/repositories/favorite_templates_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FavoriteTemplatesRepository', () {
    late AppDatabase database;
    late FavoriteTemplatesRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = FavoriteTemplatesRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('创建并按关键词查询收藏模板', () async {
      // 使用内存 Drift 数据库验证模板 JSON 落库和关键词检索链路。
      await repository.createTemplate(
        featureName: '图片压缩',
        templateName: '高质量导出',
        parameters: const <String, Object?>{'quality': 90},
      );

      final templates = await repository.getFavoriteTemplates(keyword: '质量');

      expect(templates, hasLength(1));
      expect(templates.single.featureName, '图片压缩');
      expect(templates.single.templateName, '高质量导出');
      expect(jsonDecode(templates.single.parametersJson), <String, Object?>{
        'quality': 90,
      });
    });

    test('删除和清空模板互不抛错', () async {
      await repository.createTemplate(
        featureName: '文字水印',
        templateName: '默认水印',
        parameters: const <String, Object?>{'text': 'Image Toolkit'},
      );
      final created = await repository.getFavoriteTemplates();

      await repository.deleteTemplate(created.single.id);
      expect(await repository.getFavoriteTemplates(), isEmpty);

      await repository.createTemplate(
        featureName: '图片标注',
        templateName: '红色箭头',
        parameters: const <String, Object?>{'mode': 'arrow'},
      );
      await repository.clearTemplates();

      expect(await repository.getFavoriteTemplates(), isEmpty);
    });
  });
}
