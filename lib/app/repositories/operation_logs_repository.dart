import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// 操作日志仓储，负责记录、查询和清理本地任务日志。
///
/// 设计意图：日志比历史记录更偏诊断用途，保留开始时间、完成时间和耗时，
/// 便于后续定位慢任务和失败原因；参数统一 JSON 编码，避免表结构随功能膨胀。
class OperationLogsRepository {
  OperationLogsRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<List<OperationLog>> getRecentLogs({
    int limit = 100,
    String keyword = '',
    String status = '',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _database.getRecentLogs(
      limit: limit,
      keyword: keyword,
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<int> clearLogs() {
    return _database.clearLogs();
  }

  Future<void> recordSuccess({
    required String featureName,
    required String inputPath,
    required String outputPath,
    required Map<String, Object?> parameters,
    required DateTime startedAt,
  }) async {
    await _record(
      featureName: featureName,
      inputPath: inputPath,
      outputPath: outputPath,
      parameters: parameters,
      startedAt: startedAt,
      status: 'success',
    );
  }

  Future<void> recordFailure({
    required String featureName,
    required String inputPath,
    required Map<String, Object?> parameters,
    required DateTime startedAt,
    required String errorMessage,
  }) async {
    await _record(
      featureName: featureName,
      inputPath: inputPath,
      parameters: parameters,
      startedAt: startedAt,
      status: 'failed',
      errorMessage: errorMessage,
    );
  }

  Future<void> _record({
    required String featureName,
    required String inputPath,
    required Map<String, Object?> parameters,
    required DateTime startedAt,
    required String status,
    String outputPath = '',
    String errorMessage = '',
  }) async {
    if (featureName.trim().isEmpty || inputPath.trim().isEmpty) {
      throw ArgumentError('功能名称和输入路径不能为空');
    }
    final completedAt = DateTime.now().toUtc();
    final normalizedStartedAt = startedAt.toUtc();
    final durationMs = completedAt
        .difference(normalizedStartedAt)
        .inMilliseconds
        .clamp(0, 1 << 31);

    await _database.createLog(
      OperationLogsCompanion.insert(
        featureName: featureName.trim(),
        inputPath: inputPath.trim(),
        outputPath: outputPath.trim().isEmpty
            ? const Value.absent()
            : Value(outputPath.trim()),
        parametersJson: jsonEncode(parameters),
        startedAt: normalizedStartedAt,
        completedAt: Value(completedAt),
        durationMs: Value(durationMs),
        status: status,
        errorMessage: errorMessage.trim().isEmpty
            ? const Value.absent()
            : Value(errorMessage.trim()),
      ),
    );
  }
}
