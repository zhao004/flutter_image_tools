import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// 操作历史仓储，负责压缩等功能的历史记录写入和读取。
///
/// 边界处理：参数统一 JSON 编码，写入失败交给调用方捕获并展示；读取数量
/// 小于等于 0 时返回空列表，避免无意义数据库查询。
class OperationHistoryRepository {
  OperationHistoryRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<List<OperationHistoryData>> getRecentHistory({
    int limit = 50,
    String keyword = '',
    String status = '',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _database.getRecentHistory(
      limit: limit,
      keyword: keyword,
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> clearHistory() async {
    await _database.clearHistory();
  }

  Future<int> deleteHistoryItem(int id) {
    return _database.deleteHistoryItem(id);
  }

  Future<void> recordCompressionSuccess({
    required String inputPath,
    required String outputPath,
    required int quality,
  }) async {
    await _database.createHistory(
      OperationHistoryCompanion.insert(
        featureName: '图片压缩',
        inputPath: inputPath,
        outputPath: Value(outputPath),
        parametersJson: jsonEncode(<String, Object>{'quality': quality}),
        status: 'success',
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> recordOperationSuccess({
    required String featureName,
    required String inputPath,
    required String outputPath,
    required Map<String, Object> parameters,
  }) async {
    if (featureName.trim().isEmpty || inputPath.trim().isEmpty) {
      throw ArgumentError('功能名称和输入路径不能为空');
    }
    await _database.createHistory(
      OperationHistoryCompanion.insert(
        featureName: featureName,
        inputPath: inputPath,
        outputPath: Value(outputPath),
        parametersJson: jsonEncode(parameters),
        status: 'success',
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> recordOperationFailure({
    required String featureName,
    required String inputPath,
    required Map<String, Object> parameters,
    required String errorMessage,
  }) async {
    if (featureName.trim().isEmpty || inputPath.trim().isEmpty) {
      throw ArgumentError('功能名称和输入路径不能为空');
    }
    await _database.createHistory(
      OperationHistoryCompanion.insert(
        featureName: featureName,
        inputPath: inputPath,
        parametersJson: jsonEncode(parameters),
        status: 'failed',
        errorMessage: Value(errorMessage),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> recordCompressionFailure({
    required String inputPath,
    required int quality,
    required String errorMessage,
  }) async {
    await _database.createHistory(
      OperationHistoryCompanion.insert(
        featureName: '图片压缩',
        inputPath: inputPath,
        parametersJson: jsonEncode(<String, Object>{'quality': quality}),
        status: 'failed',
        errorMessage: Value(errorMessage),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
