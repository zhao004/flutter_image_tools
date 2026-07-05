import 'dart:convert';

import '../database/database.dart';

/// 收藏模板仓储，保存用户常用的功能参数组合。
///
/// 参数统一 JSON 编码，后续压缩、裁剪、水印等模块可复用同一表结构。
class FavoriteTemplatesRepository {
  FavoriteTemplatesRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<List<FavoriteTemplate>> getFavoriteTemplates({
    int limit = 20,
    String keyword = '',
  }) {
    return _database.getFavoriteTemplates(limit: limit, keyword: keyword);
  }

  Future<int> deleteTemplate(int id) {
    return _database.deleteFavoriteTemplate(id);
  }

  Future<int> clearTemplates() {
    return _database.clearFavoriteTemplates();
  }

  Future<void> createTemplate({
    required String featureName,
    required String templateName,
    required Map<String, Object?> parameters,
  }) async {
    if (featureName.trim().isEmpty || templateName.trim().isEmpty) {
      throw ArgumentError('功能名称和模板名称不能为空');
    }
    jsonEncode(parameters);
    final now = DateTime.now().toUtc();
    await _database.createFavoriteTemplate(
      FavoriteTemplatesCompanion.insert(
        featureName: featureName.trim(),
        templateName: templateName.trim(),
        parametersJson: jsonEncode(parameters),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
