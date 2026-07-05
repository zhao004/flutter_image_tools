import 'package:drift/native.dart';
import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/repositories/operation_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationHistoryRepository', () {
    late AppDatabase database;
    late OperationHistoryRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = OperationHistoryRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('删除单条历史记录后保留其他记录', () async {
      // 单条删除只影响指定记录，避免用户清理某次失败任务时误删全部历史。
      await repository.recordOperationSuccess(
        featureName: '图片压缩',
        inputPath: '/tmp/a.jpg',
        outputPath: '/tmp/a_out.jpg',
        parameters: const <String, Object>{'quality': 80},
      );
      await repository.recordOperationFailure(
        featureName: '图片标注',
        inputPath: '/tmp/b.jpg',
        parameters: const <String, Object>{'mode': 'arrow'},
        errorMessage: '导出失败',
      );

      final beforeDelete = await repository.getRecentHistory();
      final failed = beforeDelete.firstWhere((item) => item.status == 'failed');

      final deletedCount = await repository.deleteHistoryItem(failed.id);
      final afterDelete = await repository.getRecentHistory();

      expect(deletedCount, 1);
      expect(afterDelete, hasLength(1));
      expect(afterDelete.single.status, 'success');
      expect(afterDelete.single.featureName, '图片压缩');
    });

    test('非法 ID 删除不影响历史记录', () async {
      await repository.recordOperationSuccess(
        featureName: '图片旋转',
        inputPath: '/tmp/rotate.jpg',
        outputPath: '/tmp/rotate_out.jpg',
        parameters: const <String, Object>{'degrees': 90},
      );

      final deletedCount = await repository.deleteHistoryItem(0);
      final items = await repository.getRecentHistory();

      expect(deletedCount, 0);
      expect(items, hasLength(1));
    });
  });
}
