import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/pages/grid/grid_controller.dart';
import 'package:flutter_image_tools/app/repositories/operation_history_repository.dart';
import 'package:flutter_image_tools/app/repositories/recent_files_repository.dart';
import 'package:flutter_image_tools/app/services/local_image_channel.dart';

void main() {
  group('GridController 网格边界', () {
    late AppDatabase database;
    late GridController controller;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      controller = GridController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('满尺寸网格拖动时容忍矩形宽度的浮点误差', () {
      const canvasSize = Size(559.9999999999999, 700);
      controller.gridScale.value = GridController.maxGridScale;
      // 保留布局运算产生的尾差，复现 rect.width 略大于画布宽度的手势路径。
      controller.gridOffset.value = const Offset(-45.69999999984151, 0);

      expect(
        () => controller.moveGrid(
          const Offset(double.minPositive, 0),
          canvasSize,
        ),
        returnsNormally,
      );
      final rect = controller.gridRectFor(canvasSize);
      expect(rect.left, 0);
      expect(rect.right, lessThanOrEqualTo(canvasSize.width));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(canvasSize.height));
    });

    test('小于一个逻辑像素的画布不会形成无效 clamp 区间', () {
      const canvasSize = Size(0.5, 100);

      expect(
        () => controller.setGridScale(GridController.maxGridScale, canvasSize),
        returnsNormally,
      );
      expect(
        () => controller.moveGrid(const Offset(1, 1), canvasSize),
        returnsNormally,
      );
      final rect = controller.gridRectFor(canvasSize);
      expect(rect.left.isFinite, isTrue);
      expect(rect.top.isFinite, isTrue);
      expect(rect.width, lessThanOrEqualTo(canvasSize.width));
      expect(rect.height, lessThanOrEqualTo(canvasSize.height));
    });

    test('非有限比例、偏移和手势增量不会污染网格状态', () {
      const canvasSize = Size(320, 240);
      controller.setGridScale(double.nan, canvasSize);
      expect(controller.gridScale.value, GridController.minGridScale);

      controller.gridOffset.value = const Offset(double.nan, double.infinity);
      controller.moveGrid(const Offset(4, 3), canvasSize);
      expect(controller.gridOffset.value.dx.isFinite, isTrue);
      expect(controller.gridOffset.value.dy.isFinite, isTrue);
      final recoveredOffset = controller.gridOffset.value;

      controller.moveGrid(const Offset(double.nan, 1), canvasSize);
      expect(controller.gridOffset.value, recoveredOffset);
      final rect = controller.gridRectFor(canvasSize);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(canvasSize.width));
      expect(rect.bottom, lessThanOrEqualTo(canvasSize.height));
    });
  });
}
