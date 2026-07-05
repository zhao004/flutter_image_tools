import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/repositories/operation_logs_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationLogsRepository', () {
    late AppDatabase database;
    late OperationLogsRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = OperationLogsRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('记录成功日志并按关键词查询', () async {
      // 使用真实 Drift 数据库验证仓储链路，避免日志页面依赖未落库的数据结构。
      final startedAt = DateTime.now().subtract(const Duration(seconds: 2));

      await repository.recordSuccess(
        featureName: '图片压缩',
        inputPath: '/tmp/input.jpg',
        outputPath: '/tmp/output.jpg',
        parameters: const <String, Object?>{'quality': 80},
        startedAt: startedAt,
      );

      final logs = await repository.getRecentLogs(keyword: '压缩');

      expect(logs, hasLength(1));
      expect(logs.single.status, 'success');
      expect(logs.single.outputPath, '/tmp/output.jpg');
      expect(logs.single.durationMs, isNonNegative);
    });

    test('清理日志后返回空列表', () async {
      // 清理日志只影响 operation_logs，后续可与历史记录清理保持独立。
      await repository.recordFailure(
        featureName: '格式转换',
        inputPath: '/tmp/input.png',
        parameters: const <String, Object?>{'format': 'jpg'},
        startedAt: DateTime.now(),
        errorMessage: '导出失败',
      );

      await repository.clearLogs();
      final logs = await repository.getRecentLogs();

      expect(logs, isEmpty);
    });
  });
}
