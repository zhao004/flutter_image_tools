import 'package:drift/native.dart';
import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/models/local_image_file.dart';
import 'package:flutter_image_tools/app/pages/merge/merge_controller.dart';
import 'package:flutter_image_tools/app/repositories/operation_history_repository.dart';
import 'package:flutter_image_tools/app/repositories/recent_files_repository.dart';
import 'package:flutter_image_tools/app/services/local_image_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeController 图片排序', () {
    late AppDatabase database;
    late MergeController controller;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      controller = MergeController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      );
      controller.selectedImages.value = [
        const LocalImageFile(
          path: 'first.png',
          name: 'first.png',
          sizeBytes: 1,
          mimeType: 'image/png',
          width: 100,
          height: 100,
        ),
        const LocalImageFile(
          path: 'second.png',
          name: 'second.png',
          sizeBytes: 2,
          mimeType: 'image/png',
          width: 100,
          height: 100,
        ),
        const LocalImageFile(
          path: 'third.png',
          name: 'third.png',
          sizeBytes: 3,
          mimeType: 'image/png',
          width: 100,
          height: 100,
        ),
      ];
    });

    tearDown(() async {
      controller.onClose();
      await database.close();
    });

    test('使用移除旧项后的最终索引向前和向后移动', () {
      controller.reorderSelectedImages(0, 2);

      expect(controller.selectedImages.map((image) => image.path), [
        'second.png',
        'third.png',
        'first.png',
      ]);

      controller.reorderSelectedImages(2, 0);

      expect(controller.selectedImages.map((image) => image.path), [
        'first.png',
        'second.png',
        'third.png',
      ]);
    });

    test('非法索引和忙碌状态不会改变图片顺序', () {
      final originalPaths = controller.selectedImages
          .map((image) => image.path)
          .toList(growable: false);

      controller.reorderSelectedImages(-1, 0);
      controller.reorderSelectedImages(0, 3);
      controller.isBusy.value = true;
      controller.reorderSelectedImages(0, 2);

      expect(
        controller.selectedImages.map((image) => image.path),
        originalPaths,
      );
    });
  });
}
