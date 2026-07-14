import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/models/annotated_image_file.dart';
import 'package:flutter_image_tools/app/models/local_image_file.dart';
import 'package:flutter_image_tools/app/pages/annotation/annotation_controller.dart';
import 'package:flutter_image_tools/app/repositories/operation_history_repository.dart';
import 'package:flutter_image_tools/app/repositories/recent_files_repository.dart';
import 'package:flutter_image_tools/app/services/local_image_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnnotationController 文档历史', () {
    late AppDatabase database;
    late _FakeLocalImageChannel imageChannel;
    late _TrackingHistoryRepository historyRepository;
    late AnnotationController controller;

    setUp(() {
      Get.testMode = true;
      database = AppDatabase(NativeDatabase.memory());
      imageChannel = _FakeLocalImageChannel();
      historyRepository = _TrackingHistoryRepository(database: database);
      controller = AnnotationController(
        imageChannel: imageChannel,
        historyRepository: historyRepository,
        recentFilesRepository: RecentFilesRepository(database: database),
      )..onInit();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'),
            (_) async => true,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'),
            null,
          );
      controller.onClose();
      await database.close();
      Get.reset();
    });

    test('文字图层图片旋转和遮挡共享同一撤销顺序', () {
      _selectImage(controller);
      controller.addTextLayer(text: '跨类型历史');
      controller.setRotationDegrees(90);
      controller.addMosaicStroke(const [
        Offset(100, 80),
        Offset(240, 180),
      ], kind: MosaicStrokeKind.rectangle);

      expect(controller.painterController.drawables, hasLength(1));
      expect(controller.strokes, hasLength(1));
      expect(controller.rotationDegrees.value, 90);

      controller.undo();
      expect(controller.strokes, isEmpty);
      expect(controller.rotationDegrees.value, 90);

      controller.undo();
      expect(controller.rotationDegrees.value, 0);
      expect(controller.painterController.drawables, hasLength(1));

      controller.undo();
      expect(controller.painterController.drawables, isEmpty);
      expect(controller.canUndo, isFalse);

      controller.redo();
      controller.redo();
      controller.redo();
      expect(controller.painterController.drawables, hasLength(1));
      expect(controller.rotationDegrees.value, 90);
      expect(controller.strokes, hasLength(1));
    });

    test('连续拖动只产生一个撤销节点', () {
      _selectImage(controller);
      controller.addShapeLayer(EditableLayerType.rectangle);
      final initial = controller.selectedObject.value!;

      controller.beginEditTransaction();
      controller.moveSelectedObjectBy(const Offset(10, 5));
      controller.moveSelectedObjectBy(const Offset(7, -3));
      controller.moveSelectedObjectBy(const Offset(-2, 8));
      controller.commitEditTransaction();

      expect(
        controller.selectedObject.value!.position,
        initial.position + const Offset(15, 10),
      );
      controller.undo();
      expect(controller.selectedObject.value!.position, initial.position);

      controller.undo();
      expect(controller.painterController.drawables, isEmpty);
      expect(controller.canUndo, isFalse);
    });

    test('嵌套滑杆事务不会破坏弹层取消回滚', () {
      _selectImage(controller);
      controller.addTextLayer(text: '待取消');
      final initial = controller.selectedObject.value as TextDrawable;

      controller.beginEditTransaction();
      controller.beginEditTransaction();
      controller.updateTextSize(48);
      controller.commitEditTransaction();
      controller.cancelEditTransaction();

      final restored = controller.selectedObject.value as TextDrawable;
      expect(restored.style.fontSize, initial.style.fontSize);
      controller.undo();
      expect(controller.painterController.drawables, isEmpty);
    });

    test('逻辑画布坐标不随屏幕视口变化', () {
      _selectImage(controller);
      final logicalSize = controller.logicalCanvasSizeFor(
        controller.selectedImage.value!,
      );
      controller.updateCanvasSize(const Size(320, 180));
      controller.addTextLayer(text: '稳定坐标');
      final position = controller.selectedObject.value!.position;

      controller.updateCanvasSize(const Size(900, 700));

      expect(logicalSize.width, 1000);
      expect(position.dx, closeTo(logicalSize.width / 2, 0.001));
      expect(position.dy, closeTo(logicalSize.height / 2, 0.001));
      expect(controller.selectedObject.value!.position, position);
    });

    test('重新选择图片会清空旧图层和历史', () async {
      imageChannel.pickedImages.addAll(const [
        LocalImageFile(
          path: 'first.png',
          name: 'first.png',
          sizeBytes: 100,
          mimeType: 'image/png',
          width: 1200,
          height: 800,
        ),
        LocalImageFile(
          path: 'second.png',
          name: 'second.png',
          sizeBytes: 120,
          mimeType: 'image/png',
          width: 800,
          height: 1200,
        ),
      ]);

      await controller.pickImage();
      controller.addShapeLayer(EditableLayerType.circle);
      expect(controller.canUndo, isTrue);

      await controller.pickImage();

      expect(controller.selectedImage.value!.path, 'second.png');
      expect(controller.painterController.drawables, isEmpty);
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test('无效缩放不污染预览尺寸且百分比遵守边界', () {
      _selectImage(controller);

      controller.updateResizeWidth('abc');
      expect(
        controller.previewSizeFor(controller.selectedImage.value!),
        const Size(1200, 800),
      );

      controller.updateResizePercent(500);
      expect(controller.resizePercent.value, 300);
      expect(controller.resizeWidthController.text, '3600');
      expect(controller.resizeHeightController.text, '2400');

      controller.setRotationDegrees(90);
      controller.updateResizePercent(50);
      expect(controller.resizeWidthController.text, '400');
      expect(controller.resizeHeightController.text, '600');
      expect(
        controller.previewSizeFor(controller.selectedImage.value!),
        const Size(400, 600),
      );
    });

    test('快速遮挡拖动会补齐中间采样点', () {
      final sampled = sampleContinuousRedactionPoints(const [
        Offset(0, 0),
        Offset(100, 0),
      ], 10);

      expect(sampled.first, Offset.zero);
      expect(sampled.last, const Offset(100, 0));
      for (var index = 1; index < sampled.length; index++) {
        expect(
          (sampled[index] - sampled[index - 1]).distance,
          lessThanOrEqualTo(7.5),
        );
      }
      expect(
        sampleContinuousRedactionPoints(const [
          Offset(0, 0),
          Offset(2, 0),
        ], double.nan),
        isNotEmpty,
      );
    });

    test('导出成功后历史写入失败不会记录为导出失败', () async {
      _selectImage(controller, width: 64, height: 64);
      controller.addBrushStroke(const [Offset(10, 10), Offset(40, 40)]);
      historyRepository.throwOnSuccess = true;
      imageChannel.saveRelease = Completer<void>();

      final export = controller.exportEditedImage();
      await imageChannel.saveStarted.future;
      controller.setColor(Colors.blue);
      controller.updateStrokeWidth(30);
      imageChannel.saveRelease!.complete();
      await export;

      expect(controller.result.value, isNotNull);
      expect(controller.isBusy.value, isFalse);
      expect(historyRepository.successCalls, 1);
      expect(historyRepository.failureCalls, 0);
      expect(historyRepository.successParameters!['color'], '#E53935');
      expect(historyRepository.successParameters!['strokeWidth'], 12);
      expect(imageChannel.lastOverlayBytes, isNotEmpty);
    });
  });
}

const _defaultImage = LocalImageFile(
  path: 'annotation.png',
  name: 'annotation.png',
  sizeBytes: 1024,
  mimeType: 'image/png',
  width: 1200,
  height: 800,
);

void _selectImage(
  AnnotationController controller, {
  int width = 1200,
  int height = 800,
}) {
  controller.selectedImage.value = width == 1200 && height == 800
      ? _defaultImage
      : LocalImageFile(
          path: 'annotation.png',
          name: 'annotation.png',
          sizeBytes: 1024,
          mimeType: 'image/png',
          width: width,
          height: height,
        );
}

class _FakeLocalImageChannel extends LocalImageChannel {
  final List<LocalImageFile> pickedImages = <LocalImageFile>[];
  final Completer<void> saveStarted = Completer<void>();
  Completer<void>? saveRelease;
  Uint8List lastOverlayBytes = Uint8List(0);
  int _pickIndex = 0;

  @override
  Future<LocalImageFile?> pickSingleImage() async {
    if (_pickIndex >= pickedImages.length) {
      return null;
    }
    return pickedImages[_pickIndex++];
  }

  @override
  Future<Uint8List> buildFilteredPreview({
    required LocalImageFile source,
    required String filter,
  }) async {
    return Uint8List(0);
  }

  @override
  Future<AnnotatedImageFile> saveEditedImageBytes({
    required LocalImageFile source,
    required Uint8List bytes,
    String? filter,
    int rotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
    int? resizeWidth,
    int? resizeHeight,
    double? cropAspectRatio,
  }) async {
    lastOverlayBytes = Uint8List.fromList(bytes);
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    final release = saveRelease;
    if (release != null) {
      await release.future;
    }
    return AnnotatedImageFile(
      source: source,
      outputPath: 'edited.png',
      outputSizeBytes: 321,
      mode: 'editor',
    );
  }
}

class _TrackingHistoryRepository extends OperationHistoryRepository {
  _TrackingHistoryRepository({required super.database});

  bool throwOnSuccess = false;
  int successCalls = 0;
  int failureCalls = 0;
  Map<String, Object>? successParameters;

  @override
  Future<void> recordOperationSuccess({
    required String featureName,
    required String inputPath,
    required String outputPath,
    required Map<String, Object> parameters,
  }) async {
    successCalls++;
    successParameters = Map<String, Object>.of(parameters);
    if (throwOnSuccess) {
      throw StateError('模拟历史写入失败');
    }
  }

  @override
  Future<void> recordOperationFailure({
    required String featureName,
    required String inputPath,
    required Map<String, Object> parameters,
    required String errorMessage,
  }) async {
    failureCalls++;
  }
}
