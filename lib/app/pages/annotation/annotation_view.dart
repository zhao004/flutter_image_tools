import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import '../../models/local_image_file.dart';
import '../../widgets/image_editor_scaffold.dart';
import '../filter/filter_controller.dart';
import 'annotation_controller.dart';

/// 图片编辑页，提供选图、第三方画布编辑、马赛克涂抹和保存到相册。
///
/// 构建设计：页面复用统一编辑骨架，画布区只承载可编辑图片；工具模式放入
/// 标签栏，文本、颜色和新增图层动作放入属性面板。导出、历史记录和异常处理
/// 仍由控制器负责，避免改变业务逻辑。
class AnnotationView extends GetView<AnnotationController> {
  const AnnotationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'annotation.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.image_outlined,
        emptyTitle: 'annotation.image.title'.tr,
        emptyMessage: 'annotation.image.empty'.tr,
        pickLabel: 'annotation.action.pickImage'.tr,
        repickLabel: 'annotation.action.repickImage'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.exportEditedImage,
        showPreviewInfo: false,
        showDefaultAppBarActions: false,
        expandPreviewToAvailableHeight: true,
        overlayToolbar: true,
        lockPreviewScroll: true,
        previewBuilder: (context, previewImage) =>
            _AnnotationCanvasFrame(controller: controller, image: previewImage),
        appBarActions: [_AnnotationTopActions(controller: controller)],
        bottomToolbar: _AnnotationBottomToolPanel(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'annotation.result.title'.tr,
                detail: 'annotation.result.outputSize'.trParams({
                  'size': controller.formatBytes(result.outputSizeBytes),
                }),
                tooltip: result.outputPath,
              ),
      );
    });
  }
}

class _AnnotationTopActions extends StatelessWidget {
  const _AnnotationTopActions({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final isBusy = controller.isBusy.value;
      final selectedLayer = controller.selectedObject.value;
      final selectedMosaic = controller.selectedMosaicIndex.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'annotation.action.undo'.tr,
            onPressed: image == null || isBusy || !controller.canUndo
                ? null
                : controller.undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'annotation.action.redo'.tr,
            onPressed: image == null || isBusy || !controller.canRedo
                ? null
                : controller.redo,
            icon: const Icon(Icons.redo),
          ),
          if (selectedLayer != null || selectedMosaic != null)
            IconButton(
              tooltip: 'annotation.action.deleteLayer'.tr,
              onPressed: isBusy ? null : controller.deleteSelectedObject,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'common.saveToGallery'.tr,
            onPressed: image == null || isBusy
                ? null
                : controller.exportEditedImage,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      );
    });
  }
}

class _AnnotationCanvasFrame extends StatelessWidget {
  const _AnnotationCanvasFrame({required this.controller, required this.image});

  static const double _maxPreviewWidth = 900;
  static const double _fallbackPreviewHeight = 560;

  final AnnotationController controller;
  final LocalImageFile image;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final aspectRatio = controller.previewAspectRatioFor(image);
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : _fallbackPreviewHeight;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _maxPreviewWidth,
              maxHeight: maxHeight,
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio.clamp(0.35, 2.4),
              child: _EditableCanvas(controller: controller, image: image),
            ),
          );
        },
      );
    });
  }
}

class _EditableCanvas extends StatefulWidget {
  const _EditableCanvas({required this.controller, required this.image});

  final AnnotationController controller;
  final LocalImageFile image;

  @override
  State<_EditableCanvas> createState() => _EditableCanvasState();
}

class _EditableCanvasState extends State<_EditableCanvas> {
  final List<Offset> _draftPoints = <Offset>[];
  Offset? _shapeDragStart;
  Offset? _shapeDragEnd;
  bool _isMovingSelectedMosaic = false;
  bool _isTextEditorDialogVisible = false;

  AnnotationController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            controller.updateCanvasSize(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
          }
        });

        final canvas = DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FlutterPainter.builder(
                controller: controller.painterController,
                onSelectedObjectDrawableChanged: controller.selectObject,
                builder: (context, painter) => Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) =>
                      controller.suppressLegacyTextEditorOnPointerDown(
                        event.localPosition,
                      ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTapDown: (details) async {
                      if (controller.selectTextObjectAt(
                        details.localPosition,
                      )) {
                        await _openTextEditor(context);
                      }
                    },
                    onTapUp: (details) {
                      if (_isTextEditorDialogVisible) {
                        return;
                      }
                      controller.deselectSelectedObjectIfBlankTap(
                        details.localPosition,
                      );
                    },
                    child: painter,
                  ),
                ),
              ),
              Obx(() {
                final mode = controller.mode.value;
                final shapeType = _shapeTypeForMode(mode);
                if (shapeType != null) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _startShapeDrag,
                    onPanUpdate: _updateShapeDrag,
                    onPanEnd: (_) => _finishShapeDrag(shapeType),
                    child: CustomPaint(
                      painter: _ShapeDraftPainter(
                        mode: mode,
                        start: _shapeDragStart,
                        end: _shapeDragEnd,
                        color: controller.color.value,
                        strokeWidth: controller.strokeWidth.value.toDouble(),
                        arrowStyle: controller.arrowStyle.value,
                      ),
                    ),
                  );
                }
                if (controller.selectedMosaicIndex.value != null) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) =>
                        controller.deselectSelectedObjectIfBlankTap(
                          details.localPosition,
                        ),
                    onPanStart: _startSelectedMosaicMove,
                    onPanUpdate: _moveSelectedMosaic,
                    onPanEnd: (_) => _finishSelectedMosaicMove(),
                    onPanCancel: _finishSelectedMosaicMove,
                    child: CustomPaint(
                      painter: _MosaicPainter(
                        strokes: controller.strokes,
                        draftPoints: const [],
                        draftKind: MosaicStrokeKind.freehand,
                        draftWidth: controller.strokeWidth.value.toDouble(),
                        draftColor: controller.color.value,
                      ),
                    ),
                  );
                }
                if (mode != AnnotationMode.mosaic) {
                  return IgnorePointer(
                    child: CustomPaint(
                      painter: _MosaicPainter(
                        strokes: controller.strokes,
                        draftPoints: const [],
                        draftKind: MosaicStrokeKind.freehand,
                        draftWidth: controller.strokeWidth.value.toDouble(),
                        draftColor: controller.color.value,
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _startMosaic,
                  onPanUpdate: _appendMosaic,
                  onPanEnd: _finishMosaic,
                  child: CustomPaint(
                    painter: _MosaicPainter(
                      strokes: controller.strokes,
                      draftPoints: _draftPoints,
                      draftKind: _mosaicKindForMode(
                        controller.mosaicDrawMode.value,
                      ),
                      draftWidth: controller.strokeWidth.value.toDouble(),
                      draftColor: controller.color.value,
                    ),
                  ),
                );
              }),
              _ObjectControlOverlay(controller: controller),
            ],
          ),
        );
        return _ImageAdjustmentPreview(
          controller: controller,
          image: widget.image,
          child: canvas,
        );
      },
    );
  }

  EditableLayerType? _shapeTypeForMode(AnnotationMode mode) {
    return switch (mode) {
      AnnotationMode.rectangle => EditableLayerType.rectangle,
      AnnotationMode.circle => EditableLayerType.circle,
      AnnotationMode.arrow => EditableLayerType.arrow,
      _ => null,
    };
  }

  Future<void> _openTextEditor(BuildContext context) async {
    if (_isTextEditorDialogVisible) {
      return;
    }
    _isTextEditorDialogVisible = true;
    try {
      await _showTextEditor(context, controller);
    } finally {
      _isTextEditorDialogVisible = false;
    }
  }

  void _startShapeDrag(DragStartDetails details) {
    setState(() {
      _shapeDragStart = details.localPosition;
      _shapeDragEnd = details.localPosition;
    });
  }

  void _updateShapeDrag(DragUpdateDetails details) {
    setState(() => _shapeDragEnd = details.localPosition);
  }

  void _finishShapeDrag(EditableLayerType type) {
    final start = _shapeDragStart;
    final end = _shapeDragEnd;
    if (start != null && end != null) {
      controller.addShapeFromDrag(type, start, end);
    }
    setState(() {
      _shapeDragStart = null;
      _shapeDragEnd = null;
    });
  }

  void _startSelectedMosaicMove(DragStartDetails details) {
    _isMovingSelectedMosaic = controller.selectMosaicAt(details.localPosition);
  }

  void _moveSelectedMosaic(DragUpdateDetails details) {
    if (!_isMovingSelectedMosaic) {
      return;
    }
    controller.moveSelectedMosaicBy(details.delta);
  }

  void _finishSelectedMosaicMove() {
    _isMovingSelectedMosaic = false;
  }

  void _startMosaic(DragStartDetails details) {
    setState(() {
      _draftPoints
        ..clear()
        ..add(details.localPosition);
    });
  }

  void _appendMosaic(DragUpdateDetails details) {
    setState(() {
      if (controller.mosaicDrawMode.value == MosaicDrawMode.freehand) {
        _draftPoints.add(details.localPosition);
      } else if (_draftPoints.isNotEmpty) {
        _draftPoints
          ..removeRange(1, _draftPoints.length)
          ..add(details.localPosition);
      }
    });
  }

  void _finishMosaic(DragEndDetails details) {
    controller.addMosaicStroke(
      _draftPoints,
      kind: _mosaicKindForMode(controller.mosaicDrawMode.value),
    );
    setState(_draftPoints.clear);
  }

  MosaicStrokeKind _mosaicKindForMode(MosaicDrawMode mode) {
    return switch (mode) {
      MosaicDrawMode.freehand => MosaicStrokeKind.freehand,
      MosaicDrawMode.rectangle => MosaicStrokeKind.rectangle,
      MosaicDrawMode.circle => MosaicStrokeKind.circle,
    };
  }
}

class _ImageAdjustmentPreview extends StatelessWidget {
  const _ImageAdjustmentPreview({
    required this.controller,
    required this.image,
    required this.child,
  });

  final AnnotationController controller;
  final LocalImageFile image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.editRevision.value;
      final colorFilter = _colorFilterFor(controller.filter.value);

      final sourceAspectRatio = image.hasValidDimensions
          ? image.width / image.height
          : 1.0;
      final cropAspectRatio =
          controller.cropPreset.value.aspectRatio ?? sourceAspectRatio;
      Widget preview = SizedBox(
        width: 1000,
        height: 1000 / cropAspectRatio.clamp(0.1, 10),
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: 1000,
              height: 1000 / sourceAspectRatio.clamp(0.1, 10),
              child: child,
            ),
          ),
        ),
      );

      final normalizedDegrees = controller.rotationDegrees.value % 360;
      if (normalizedDegrees != 0 && normalizedDegrees % 90 == 0) {
        preview = RotatedBox(
          quarterTurns: normalizedDegrees ~/ 90,
          child: preview,
        );
      } else if (normalizedDegrees != 0) {
        preview = Transform.rotate(
          angle: normalizedDegrees / 180 * math.pi,
          child: preview,
        );
      }
      if (controller.flipHorizontal.value || controller.flipVertical.value) {
        preview = Transform.scale(
          scaleX: controller.flipHorizontal.value ? -1 : 1,
          scaleY: controller.flipVertical.value ? -1 : 1,
          child: preview,
        );
      }
      if (colorFilter != null) {
        preview = ColorFiltered(colorFilter: colorFilter, child: preview);
      }

      return ClipRect(
        key: const ValueKey('annotation-adjustment-preview'),
        child: _isImageProcessingMode(controller.mode.value)
            ? IgnorePointer(
                // 设计意图：处理标签只预览整图变换；切回画笔等工具时仍保留同一套预览，
                // 但恢复画布命中，避免工具切换后旋转、翻转、裁剪等视觉状态丢失。
                child: FittedBox(
                  fit: BoxFit.fill,
                  clipBehavior: Clip.hardEdge,
                  child: preview,
                ),
              )
            : FittedBox(
                fit: BoxFit.fill,
                clipBehavior: Clip.hardEdge,
                child: preview,
              ),
      );
    });
  }

  bool _isImageProcessingMode(AnnotationMode mode) {
    return switch (mode) {
      AnnotationMode.filter ||
      AnnotationMode.rotate ||
      AnnotationMode.flip ||
      AnnotationMode.resize ||
      AnnotationMode.crop => true,
      AnnotationMode.select ||
      AnnotationMode.brush ||
      AnnotationMode.mosaic ||
      AnnotationMode.text ||
      AnnotationMode.rectangle ||
      AnnotationMode.circle ||
      AnnotationMode.arrow => false,
    };
  }

  ColorFilter? _colorFilterFor(ImageFilterType? filter) {
    if (filter == null) {
      return null;
    }
    switch (filter) {
      case ImageFilterType.grayscale:
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.monochrome:
        return const ColorFilter.matrix([
          1.5,
          1.5,
          1.5,
          0,
          -180,
          1.5,
          1.5,
          1.5,
          0,
          -180,
          1.5,
          1.5,
          1.5,
          0,
          -180,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.sepia:
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.invert:
        return const ColorFilter.matrix([
          -1,
          0,
          0,
          0,
          255,
          0,
          -1,
          0,
          0,
          255,
          0,
          0,
          -1,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.warm:
        return const ColorFilter.matrix([
          1.12,
          0,
          0,
          0,
          10,
          0,
          1.02,
          0,
          0,
          2,
          0,
          0,
          0.90,
          0,
          -8,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.cool:
        return const ColorFilter.matrix([
          0.90,
          0,
          0,
          0,
          -8,
          0,
          1.02,
          0,
          0,
          2,
          0,
          0,
          1.14,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.hdr:
        return const ColorFilter.matrix([
          1.25,
          0,
          0,
          0,
          -16,
          0,
          1.25,
          0,
          0,
          -16,
          0,
          0,
          1.25,
          0,
          -16,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.film:
        return const ColorFilter.matrix([
          1.05,
          0.05,
          0,
          0,
          8,
          0.04,
          0.98,
          0.02,
          0,
          4,
          0,
          0.06,
          0.92,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.sharpen:
        return const ColorFilter.matrix([
          1.12,
          0,
          0,
          0,
          -6,
          0,
          1.12,
          0,
          0,
          -6,
          0,
          0,
          1.12,
          0,
          -6,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.soften:
        return const ColorFilter.matrix([
          0.94,
          0.03,
          0.03,
          0,
          4,
          0.03,
          0.94,
          0.03,
          0,
          4,
          0.03,
          0.03,
          0.94,
          0,
          4,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }
}

class _AnnotationBottomToolPanel extends StatelessWidget {
  const _AnnotationBottomToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeCategoryId = _activeCategoryId;
      return EditorDynamicToolPanel(
        categories: _toolCategories(showSubItems: _shouldShowPanel),
        activeCategoryId: activeCategoryId,
        activeSubItemId: _activeSubItemId(activeCategoryId),
        onCategorySelected: (category) =>
            _handleCategorySelected(context, category.id),
        onSubItemSelected: (item) =>
            _handleSubItemSelected(context, activeCategoryId, item.id),
        activePanel: _activePanel(),
        maxPanelHeight: 260,
        showPanelHeader: false,
        compactPanel: true,
      );
    });
  }

  List<ToolCategory> _toolCategories({required bool showSubItems}) {
    return [
      ToolCategory(
        id: 'markup',
        name: 'annotation.mode.markup'.tr,
        icon: Icons.edit_outlined,
        subItems: showSubItems
            ? [
                ToolSubItem(
                  id: AnnotationMode.brush.value,
                  name: AnnotationMode.brush.label,
                  icon: Icons.brush_outlined,
                ),
                ToolSubItem(
                  id: AnnotationMode.rectangle.value,
                  name: AnnotationMode.rectangle.label,
                  icon: Icons.crop_square,
                ),
                ToolSubItem(
                  id: AnnotationMode.circle.value,
                  name: AnnotationMode.circle.label,
                  icon: Icons.circle_outlined,
                ),
                ToolSubItem(
                  id: AnnotationMode.arrow.value,
                  name: AnnotationMode.arrow.label,
                  icon: Icons.arrow_forward,
                ),
              ]
            : const <ToolSubItem>[],
      ),
      ToolCategory(
        id: AnnotationMode.mosaic.value,
        name: AnnotationMode.mosaic.label,
        icon: Icons.grid_on_outlined,
        subItems: showSubItems
            ? [
                ToolSubItem(
                  id: MosaicDrawMode.freehand.name,
                  name: MosaicDrawMode.freehand.label,
                  icon: Icons.gesture,
                ),
                ToolSubItem(
                  id: MosaicDrawMode.rectangle.name,
                  name: MosaicDrawMode.rectangle.label,
                  icon: Icons.crop_square,
                ),
                ToolSubItem(
                  id: MosaicDrawMode.circle.name,
                  name: MosaicDrawMode.circle.label,
                  icon: Icons.circle_outlined,
                ),
              ]
            : const <ToolSubItem>[],
      ),
      ToolCategory(
        id: AnnotationMode.text.value,
        name: AnnotationMode.text.label,
        icon: Icons.text_fields,
      ),
      ToolCategory(
        id: AnnotationMode.filter.value,
        name: AnnotationMode.filter.label,
        icon: Icons.filter_vintage_outlined,
      ),
      ToolCategory(
        id: AnnotationMode.rotate.value,
        name: AnnotationMode.rotate.label,
        icon: Icons.rotate_right,
      ),
      ToolCategory(
        id: AnnotationMode.flip.value,
        name: AnnotationMode.flip.label,
        icon: Icons.flip_outlined,
      ),
      ToolCategory(
        id: AnnotationMode.resize.value,
        name: AnnotationMode.resize.label,
        icon: Icons.aspect_ratio_outlined,
      ),
      ToolCategory(
        id: AnnotationMode.crop.value,
        name: AnnotationMode.crop.label,
        icon: Icons.crop_outlined,
      ),
    ];
  }

  bool get _shouldShowPanel {
    final mode = controller.mode.value;
    final hasSelectedLayer = controller.selectedObject.value != null;
    final hasSelectedMosaic = controller.selectedMosaicIndex.value != null;
    if (!controller.isPropertyPanelVisible.value) {
      return false;
    }
    return mode != AnnotationMode.select ||
        hasSelectedLayer ||
        hasSelectedMosaic;
  }

  Widget? _activePanel() {
    return _shouldShowPanel
        ? _AnnotationPropertyPanel(controller: controller)
        : null;
  }

  String? get _activeCategoryId {
    if (controller.selectedMosaicIndex.value != null) {
      return AnnotationMode.mosaic.value;
    }
    final selectedObject = controller.selectedObject.value;
    if (selectedObject is TextDrawable) {
      return AnnotationMode.text.value;
    }
    if (selectedObject is ShapeDrawable ||
        selectedObject is EditableArrowDrawable) {
      return 'markup';
    }
    final mode = controller.mode.value;
    if (_isMarkupMode(mode)) {
      return 'markup';
    }
    if (mode == AnnotationMode.select) {
      return null;
    }
    return mode.value;
  }

  String? _activeSubItemId(String? activeCategoryId) {
    if (activeCategoryId == 'markup') {
      final selectedObject = controller.selectedObject.value;
      if (selectedObject is EditableArrowDrawable) {
        return AnnotationMode.arrow.value;
      }
      if (selectedObject is RectangleDrawable) {
        return AnnotationMode.rectangle.value;
      }
      if (selectedObject is OvalDrawable) {
        return AnnotationMode.circle.value;
      }
      final mode = controller.mode.value;
      return _isMarkupMode(mode) ? mode.value : null;
    }
    if (activeCategoryId == AnnotationMode.mosaic.value) {
      return controller.mosaicDrawMode.value.name;
    }
    return null;
  }

  Future<void> _handleCategorySelected(
    BuildContext context,
    String categoryId,
  ) async {
    if (categoryId == 'markup') {
      final mode = controller.mode.value;
      if (_isMarkupMode(mode)) {
        controller.setMode(mode);
      } else {
        controller.setMode(AnnotationMode.brush);
      }
      return;
    }
    if (categoryId == AnnotationMode.mosaic.value) {
      controller.setMosaicDrawMode(controller.mosaicDrawMode.value);
      return;
    }
    if (categoryId == AnnotationMode.text.value) {
      controller.setMode(AnnotationMode.text);
      controller.createDefaultTextLayer();
      await _showTextEditor(context, controller);
      return;
    }
    final mode = AnnotationMode.values.firstWhereOrNull(
      (value) => value.value == categoryId,
    );
    if (mode != null) {
      controller.setMode(mode);
    }
  }

  void _handleSubItemSelected(
    BuildContext context,
    String? activeCategoryId,
    String itemId,
  ) {
    if (activeCategoryId == 'markup') {
      final mode = AnnotationMode.values.firstWhereOrNull(
        (value) => value.value == itemId,
      );
      if (mode == null) {
        return;
      }
      switch (mode) {
        case AnnotationMode.brush:
          controller.setMode(AnnotationMode.brush);
        case AnnotationMode.rectangle:
          controller.selectShapeTool(EditableLayerType.rectangle);
        case AnnotationMode.circle:
          controller.selectShapeTool(EditableLayerType.circle);
        case AnnotationMode.arrow:
          controller.selectShapeTool(EditableLayerType.arrow);
        case AnnotationMode.select:
        case AnnotationMode.mosaic:
        case AnnotationMode.text:
        case AnnotationMode.filter:
        case AnnotationMode.rotate:
        case AnnotationMode.flip:
        case AnnotationMode.resize:
        case AnnotationMode.crop:
          break;
      }
      return;
    }
    if (activeCategoryId == AnnotationMode.mosaic.value) {
      final mode = MosaicDrawMode.values.firstWhereOrNull(
        (value) => value.name == itemId,
      );
      if (mode != null) {
        controller.setMosaicDrawMode(mode);
      }
    }
  }

  bool _isMarkupMode(AnnotationMode mode) {
    return switch (mode) {
      AnnotationMode.brush ||
      AnnotationMode.rectangle ||
      AnnotationMode.circle ||
      AnnotationMode.arrow => true,
      AnnotationMode.select ||
      AnnotationMode.mosaic ||
      AnnotationMode.text ||
      AnnotationMode.filter ||
      AnnotationMode.rotate ||
      AnnotationMode.flip ||
      AnnotationMode.resize ||
      AnnotationMode.crop => false,
    };
  }
}

Future<void> _showTextEditor(
  BuildContext context,
  AnnotationController controller,
) async {
  // 文本弹窗已经承载文本属性编辑，打开前收起常驻面板，避免同一文本出现两套设置入口。
  controller.closePropertyPanel();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'annotation.action.closePanel'.tr,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              TextField(
                controller: controller.textController,
                autofocus: true,
                maxLength: 40,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'annotation.text.label'.tr,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              _TextEditorStyleControls(controller: controller),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {
                    if (controller.updateSelectedTextLayer()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('common.confirm'.tr),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AnnotationPropertyPanel extends StatelessWidget {
  const _AnnotationPropertyPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showMosaicPanel =
          controller.mode.value == AnnotationMode.mosaic ||
          controller.selectedMosaicIndex.value != null;
      if (showMosaicPanel) {
        return _MosaicSingleLinePropertyPanel(controller: controller);
      }
      return _FullAnnotationPropertyPanel(controller: controller);
    });
  }
}

class _FullAnnotationPropertyPanel extends StatelessWidget {
  const _FullAnnotationPropertyPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'annotation.action.closePanel'.tr,
          visualDensity: VisualDensity.compact,
          onPressed: controller.closePropertyPanel,
          icon: const Icon(Icons.close),
        ),
        _TextToolPanel(controller: controller),
        _FilterToolPanel(controller: controller),
        _RotateToolPanel(controller: controller),
        _FlipToolPanel(controller: controller),
        _ResizeToolPanel(controller: controller),
        _CropToolPanel(controller: controller),
        _ArrowStyleControls(controller: controller),
        _StrokeAndColorControls(controller: controller),
      ],
    );
  }
}

class _MosaicSingleLinePropertyPanel extends StatelessWidget {
  const _MosaicSingleLinePropertyPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final drawMode = controller.mosaicDrawMode.value;
      final strokeValue = controller.strokeWidth.value;
      final showStrokeSlider = drawMode == MosaicDrawMode.freehand;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showAnnotationColorPicker(context, controller),
            icon: _ColorSwatch(color: controller.color.value),
            label: Text(controller.colorHex),
          ),
          if (showStrokeSlider) ...[
            const SizedBox(width: 10),
            Text('annotation.strokeWidth'.trParams({'value': '$strokeValue'})),
            SizedBox(
              width: 160,
              child: Slider(
                min: 2,
                max: 60,
                divisions: 58,
                value: strokeValue.toDouble(),
                onChanged: controller.updateStrokeWidth,
              ),
            ),
          ],
          IconButton(
            tooltip: 'annotation.action.closePanel'.tr,
            visualDensity: VisualDensity.compact,
            onPressed: controller.closePropertyPanel,
            icon: const Icon(Icons.close),
          ),
        ],
      );
    });
  }
}

class _FilterToolPanel extends StatelessWidget {
  const _FilterToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value != AnnotationMode.filter) {
        return const SizedBox.shrink();
      }
      return _PanelBlock(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChoicePill(
              label: 'annotation.filter.none'.tr,
              selected: controller.filter.value == null,
              onSelected: () => controller.setFilter(null),
            ),
            ...ImageFilterType.values.map(
              (filter) => _ChoicePill(
                label: filter.label,
                selected: controller.filter.value == filter,
                onSelected: () => controller.setFilter(filter),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _RotateToolPanel extends StatelessWidget {
  const _RotateToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value != AnnotationMode.rotate) {
        return const SizedBox.shrink();
      }
      final degrees = controller.rotationDegrees.value;
      return _PanelBlock(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconActionChip(
              icon: Icons.rotate_left,
              label: 'rotate.angle.left90'.tr,
              onTap: () => controller.rotateByQuarterTurn(-90),
            ),
            const SizedBox(width: 8),
            _IconActionChip(
              icon: Icons.rotate_right,
              label: 'rotate.angle.right90'.tr,
              onTap: () => controller.rotateByQuarterTurn(90),
            ),
            const SizedBox(width: 8),
            _IconActionChip(
              icon: Icons.refresh,
              label: 'annotation.reset'.tr,
              onTap: () => controller.setRotationDegrees(0),
            ),
            const SizedBox(width: 10),
            Text('rotate.angle.custom'.trParams({'degrees': '$degrees'})),
            SizedBox(
              width: 170,
              child: Slider(
                min: -180,
                max: 180,
                divisions: 360,
                value: degrees.toDouble().clamp(-180, 180),
                onChanged: (value) =>
                    controller.setRotationDegrees(value.round()),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _FlipToolPanel extends StatelessWidget {
  const _FlipToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value != AnnotationMode.flip) {
        return const SizedBox.shrink();
      }
      return _PanelBlock(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilterChip(
              avatar: const Icon(Icons.swap_horiz, size: 18),
              label: Text('flip.direction.horizontal'.tr),
              selected: controller.flipHorizontal.value,
              onSelected: controller.setFlipHorizontal,
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: const Icon(Icons.swap_vert, size: 18),
              label: Text('flip.direction.vertical'.tr),
              selected: controller.flipVertical.value,
              onSelected: controller.setFlipVertical,
            ),
          ],
        ),
      );
    });
  }
}

class _ResizeToolPanel extends StatelessWidget {
  const _ResizeToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value != AnnotationMode.resize) {
        return const SizedBox.shrink();
      }
      final image = controller.selectedImage.value;
      final widthText = controller.resizeWidthController.text.trim().isNotEmpty
          ? controller.resizeWidthController.text.trim()
          : image?.width.toString() ?? '';
      final heightText =
          controller.resizeHeightController.text.trim().isNotEmpty
          ? controller.resizeHeightController.text.trim()
          : image?.height.toString() ?? '';
      final sizeLabel = widthText.isNotEmpty && heightText.isNotEmpty
          ? '$widthText × $heightText px'
          : 'resize.size.title'.tr;
      return _PanelBlock(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PropertyGroupChip(
              icon: Icons.aspect_ratio_outlined,
              label: sizeLabel,
              onTap: () => _showResizeSettingsPanel(context, controller),
            ),
            const SizedBox(width: 10),
            Text(
              'resize.size.percent'.trParams({
                'percent': controller.resizePercent.value.round().toString(),
              }),
            ),
            SizedBox(
              width: 170,
              child: Slider(
                min: 10,
                max: 300,
                divisions: 290,
                value: controller.resizePercent.value.clamp(10, 300),
                onChanged: controller.updateResizePercent,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _CropToolPanel extends StatelessWidget {
  const _CropToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value != AnnotationMode.crop) {
        return const SizedBox.shrink();
      }
      return _PanelBlock(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: AnnotationCropPreset.values
              .map(
                (preset) => _ChoicePill(
                  label: preset.label,
                  selected: controller.cropPreset.value == preset,
                  onSelected: () => controller.setCropPreset(preset),
                ),
              )
              .toList(growable: false),
        ),
      );
    });
  }
}

class _ArrowStyleControls extends StatelessWidget {
  const _ArrowStyleControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedObject = controller.selectedObject.value;
      final showControls =
          controller.mode.value == AnnotationMode.arrow ||
          selectedObject is EditableArrowDrawable;
      if (!showControls) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: SegmentedButton<EditableArrowStyle>(
          segments: EditableArrowStyle.values
              .map(
                (style) => ButtonSegment<EditableArrowStyle>(
                  value: style,
                  label: Text(style.label),
                ),
              )
              .toList(growable: false),
          selected: {controller.arrowStyle.value},
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              controller.setArrowStyle(values.first);
            }
          },
        ),
      );
    });
  }
}

class _TextToolPanel extends StatelessWidget {
  const _TextToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedObject = controller.selectedObject.value;
      final showControls =
          controller.mode.value == AnnotationMode.text ||
          selectedObject is TextDrawable;
      if (!showControls) {
        return const SizedBox.shrink();
      }
      return _PanelBlock(child: _TextStyleControls(controller: controller));
    });
  }
}

class _TextStyleControls extends StatelessWidget {
  const _TextStyleControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final textSize = controller.textSize.value.round();
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('annotation.text.size'.trParams({'value': '$textSize'})),
          SizedBox(
            width: 160,
            child: Slider(
              min: AnnotationController.minTextSize,
              max: AnnotationController.maxTextSize,
              divisions:
                  (AnnotationController.maxTextSize -
                          AnnotationController.minTextSize)
                      .round(),
              value: controller.textSize.value,
              onChanged: controller.updateTextSize,
            ),
          ),
          const SizedBox(width: 8),
          _PropertyGroupChip(
            icon: Icons.font_download_outlined,
            label:
                '${'annotation.text.font'.tr}: ${controller.textFont.value.label}',
            onTap: () => _showTextFontPicker(context, controller),
          ),
        ],
      );
    });
  }
}

class _TextEditorStyleControls extends StatelessWidget {
  const _TextEditorStyleControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final textSize = controller.textSize.value.round();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('annotation.text.size'.trParams({'value': '$textSize'})),
              Expanded(
                child: Slider(
                  min: AnnotationController.minTextSize,
                  max: AnnotationController.maxTextSize,
                  divisions:
                      (AnnotationController.maxTextSize -
                              AnnotationController.minTextSize)
                          .round(),
                  value: controller.textSize.value,
                  onChanged: controller.updateTextSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('annotation.text.font'.tr),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<AnnotationTextFont>(
              segments: AnnotationTextFont.values
                  .map(
                    (font) => ButtonSegment<AnnotationTextFont>(
                      value: font,
                      label: Text(font.label),
                    ),
                  )
                  .toList(growable: false),
              selected: {controller.textFont.value},
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  controller.setTextFont(values.first);
                }
              },
            ),
          ),
        ],
      );
    });
  }
}

class _StrokeAndColorControls extends StatelessWidget {
  const _StrokeAndColorControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showStrokeControls = switch (controller.mode.value) {
        AnnotationMode.brush ||
        AnnotationMode.rectangle ||
        AnnotationMode.circle ||
        AnnotationMode.arrow => true,
        AnnotationMode.mosaic =>
          controller.mosaicDrawMode.value == MosaicDrawMode.freehand,
        AnnotationMode.select =>
          controller.selectedObject.value is ShapeDrawable,
        AnnotationMode.text ||
        AnnotationMode.filter ||
        AnnotationMode.rotate ||
        AnnotationMode.flip ||
        AnnotationMode.resize ||
        AnnotationMode.crop => false,
      };
      final showColorControls = switch (controller.mode.value) {
        AnnotationMode.brush ||
        AnnotationMode.rectangle ||
        AnnotationMode.circle ||
        AnnotationMode.arrow ||
        AnnotationMode.text ||
        AnnotationMode.mosaic => true,
        AnnotationMode.select => controller.selectedObject.value != null,
        AnnotationMode.filter ||
        AnnotationMode.rotate ||
        AnnotationMode.flip ||
        AnnotationMode.resize ||
        AnnotationMode.crop => false,
      };
      if (!showStrokeControls && !showColorControls) {
        return const SizedBox.shrink();
      }
      final strokeValue = controller.strokeWidth.value;
      final selectedColor = controller.color.value;
      final colorHex = controller.colorHex;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showColorControls) ...[
              OutlinedButton.icon(
                onPressed: () =>
                    _showAnnotationColorPicker(context, controller),
                icon: _ColorSwatch(color: selectedColor),
                label: Text(colorHex),
              ),
              if (showStrokeControls) const SizedBox(width: 10),
            ],
            if (showStrokeControls) ...[
              Text(
                'annotation.strokeWidth'.trParams({'value': '$strokeValue'}),
              ),
              SizedBox(
                width: 160,
                child: Slider(
                  min: 2,
                  max: 60,
                  divisions: 58,
                  value: strokeValue.toDouble(),
                  onChanged: controller.updateStrokeWidth,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const SizedBox(width: 18, height: 18),
    );
  }
}

Future<void> _showAnnotationColorPicker(
  BuildContext context,
  AnnotationController controller,
) async {
  final selectedColor = await showColorPickerDialog(
    context,
    controller.color.value.withValues(alpha: 1),
    title: Text('annotation.color.title'.tr),
    pickersEnabled: const <ColorPickerType, bool>{
      ColorPickerType.both: false,
      ColorPickerType.primary: true,
      ColorPickerType.accent: true,
      ColorPickerType.bw: true,
      ColorPickerType.custom: false,
      ColorPickerType.wheel: true,
    },
    enableOpacity: false,
    showColorCode: true,
    wheelDiameter: 190,
    copyPasteBehavior: const ColorPickerCopyPasteBehavior(
      copyButton: true,
      pasteButton: true,
      copyFormat: ColorPickerCopyFormat.numHexRRGGBB,
      parseShortHexCode: true,
    ),
    actionButtons: ColorPickerActionButtons(
      dialogOkButtonLabel: 'common.confirm'.tr,
      dialogCancelButtonLabel: 'common.cancel'.tr,
      dialogOkButtonType: ColorPickerActionButtonType.filled,
    ),
  );

  if (!context.mounted) {
    return;
  }
  controller.setColor(selectedColor.withValues(alpha: 1));
}

class _PanelBlock extends StatelessWidget {
  const _PanelBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(right: 10), child: child);
  }
}

class _PropertyGroupChip extends StatelessWidget {
  const _PropertyGroupChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      onPressed: onTap,
    );
  }
}

Future<void> _showTextFontPicker(
  BuildContext context,
  AnnotationController controller,
) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'annotation.action.closePanel'.tr,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<AnnotationTextFont>(
                    segments: AnnotationTextFont.values
                        .map(
                          (font) => ButtonSegment<AnnotationTextFont>(
                            value: font,
                            label: Text(font.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: {controller.textFont.value},
                    onSelectionChanged: (values) {
                      if (values.isNotEmpty) {
                        controller.setTextFont(values.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showResizeSettingsPanel(
  BuildContext context,
  AnnotationController controller,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'annotation.action.closePanel'.tr,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _DimensionField(
                        label: 'resize.size.width'.tr,
                        controller: controller.resizeWidthController,
                        onChanged: controller.updateResizeWidth,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DimensionField(
                        label: 'resize.size.height'.tr,
                        controller: controller.resizeHeightController,
                        onChanged: controller.updateResizeHeight,
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('resize.size.keepAspectRatio'.tr),
                  value: controller.resizeKeepAspectRatio.value,
                  onChanged: controller.setResizeKeepAspectRatio,
                ),
                Row(
                  children: [
                    Text(
                      'resize.size.percent'.trParams({
                        'percent': controller.resizePercent.value
                            .round()
                            .toString(),
                      }),
                    ),
                    Expanded(
                      child: Slider(
                        min: 10,
                        max: 300,
                        divisions: 290,
                        value: controller.resizePercent.value.clamp(10, 300),
                        onChanged: controller.updateResizePercent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _IconActionChip extends StatelessWidget {
  const _IconActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'px',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _ObjectControlOverlay extends StatelessWidget {
  const _ObjectControlOverlay({required this.controller});

  static const double _controlSize = 28;
  static const double _dragDotSize = 18;

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final geometry = controller.selectedControlGeometry;
      if (geometry == null) {
        return const SizedBox.shrink();
      }
      return Stack(
        children: [
          for (final handle in geometry.shapeScaleHandles)
            _PositionedControl(
              center: handle.center,
              size: _dragDotSize,
              child: _ShapeScaleHandle(
                onPanUpdate: (details) =>
                    controller.resizeSelectedShapeFromCorner(
                      corner: handle.corner,
                      point: _canvasPointFromHandle(
                        center: handle.center,
                        size: _dragDotSize,
                        localPosition: details.localPosition,
                      ),
                    ),
              ),
            ),
          if (geometry.rotateHandle != null)
            _PositionedControl(
              center: geometry.rotateHandle!,
              size: _controlSize,
              child: _RotationHandle(
                onPanUpdate: (details) => controller.rotateSelectedShapeTo(
                  _canvasPointFromHandle(
                    center: geometry.rotateHandle!,
                    size: _controlSize,
                    localPosition: details.localPosition,
                  ),
                ),
              ),
            ),
          if (geometry.arrowStart != null)
            _PositionedControl(
              center: geometry.arrowStart!,
              size: _dragDotSize,
              child: _ArrowEndpointHandle(
                onPanUpdate: (details) =>
                    controller.updateSelectedArrowScaleHandle(
                      isHead: false,
                      point: _canvasPointFromHandle(
                        center: geometry.arrowStart!,
                        size: _dragDotSize,
                        localPosition: details.localPosition,
                      ),
                    ),
              ),
            ),
          if (geometry.arrowEnd != null)
            _PositionedControl(
              center: geometry.arrowEnd!,
              size: _dragDotSize,
              child: _ArrowEndpointHandle(
                onPanUpdate: (details) =>
                    controller.updateSelectedArrowScaleHandle(
                      isHead: true,
                      point: _canvasPointFromHandle(
                        center: geometry.arrowEnd!,
                        size: _dragDotSize,
                        localPosition: details.localPosition,
                      ),
                    ),
              ),
            ),
          if (geometry.arrowDirectionHandle != null)
            _PositionedControl(
              center: geometry.arrowDirectionHandle!,
              size: _controlSize,
              child: _ArrowDirectionHandle(
                onPanUpdate: (details) => controller.rotateSelectedArrowTo(
                  _canvasPointFromHandle(
                    center: geometry.arrowDirectionHandle!,
                    size: _controlSize,
                    localPosition: details.localPosition,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Offset _canvasPointFromHandle({
    required Offset center,
    required double size,
    required Offset localPosition,
  }) {
    final origin = Offset(center.dx - size / 2, center.dy - size / 2);
    return origin + localPosition;
  }
}

class _PositionedControl extends StatelessWidget {
  const _PositionedControl({
    required this.center,
    required this.size,
    required this.child,
  });

  final Offset center;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: child,
    );
  }
}

class _RotationHandle extends StatelessWidget {
  const _RotationHandle({required this.onPanUpdate});

  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.onPrimary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.rotate_right, color: colorScheme.onPrimary, size: 18),
      ),
    );
  }
}

class _ArrowEndpointHandle extends StatelessWidget {
  const _ArrowEndpointHandle({required this.onPanUpdate});

  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeScaleHandle extends StatelessWidget {
  const _ShapeScaleHandle({required this.onPanUpdate});

  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowDirectionHandle extends StatelessWidget {
  const _ArrowDirectionHandle({required this.onPanUpdate});

  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.onPrimary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.navigation_outlined,
          color: colorScheme.onPrimary,
          size: 17,
        ),
      ),
    );
  }
}

class _MosaicPainter extends CustomPainter {
  const _MosaicPainter({
    required this.strokes,
    required this.draftPoints,
    required this.draftKind,
    required this.draftWidth,
    required this.draftColor,
  });

  final List<DrawingStroke> strokes;
  final List<Offset> draftPoints;
  final MosaicStrokeKind draftKind;
  final double draftWidth;
  final Color draftColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final stroke in strokes) {
      paint.color = stroke.color.withValues(alpha: 1);
      _paintStroke(canvas, paint, stroke.kind, stroke.points, stroke.width);
    }
    paint.color = draftColor.withValues(alpha: 1);
    _paintStroke(canvas, paint, draftKind, draftPoints, draftWidth);
  }

  void _paintStroke(
    Canvas canvas,
    Paint paint,
    MosaicStrokeKind kind,
    List<Offset> points,
    double width,
  ) {
    if (points.length < 2) {
      return;
    }
    switch (kind) {
      case MosaicStrokeKind.freehand:
        for (final point in points) {
          canvas.drawRect(
            Rect.fromCenter(
              center: point,
              width: width * 1.8,
              height: width * 1.8,
            ),
            paint,
          );
        }
      case MosaicStrokeKind.rectangle:
        canvas.drawRect(_rectFromPoints(points.first, points.last), paint);
      case MosaicStrokeKind.circle:
        canvas.drawOval(_rectFromPoints(points.first, points.last), paint);
    }
  }

  Rect _rectFromPoints(Offset start, Offset end) {
    return Rect.fromLTRB(
      start.dx < end.dx ? start.dx : end.dx,
      start.dy < end.dy ? start.dy : end.dy,
      start.dx > end.dx ? start.dx : end.dx,
      start.dy > end.dy ? start.dy : end.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _MosaicPainter oldDelegate) {
    return true;
  }
}

class _ShapeDraftPainter extends CustomPainter {
  const _ShapeDraftPainter({
    required this.mode,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    required this.arrowStyle,
  });

  final AnnotationMode mode;
  final Offset? start;
  final Offset? end;
  final Color color;
  final double strokeWidth;
  final EditableArrowStyle arrowStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final from = start;
    final to = end;
    if (from == null || to == null) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth.clamp(2, 32)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (mode) {
      case AnnotationMode.rectangle:
        canvas.drawRect(_rectFromPoints(from, to), paint);
      case AnnotationMode.circle:
        final delta = to - from;
        final side = delta.dx.abs() > delta.dy.abs()
            ? delta.dx.abs()
            : delta.dy.abs();
        final rect = Rect.fromCenter(
          center: Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2),
          width: side,
          height: side,
        );
        canvas.drawOval(rect, paint);
      case AnnotationMode.arrow:
        canvas.drawLine(from, to, paint);
        _drawArrowHead(canvas, paint, from, to);
      case AnnotationMode.select:
      case AnnotationMode.brush:
      case AnnotationMode.mosaic:
      case AnnotationMode.text:
      case AnnotationMode.filter:
      case AnnotationMode.rotate:
      case AnnotationMode.flip:
      case AnnotationMode.resize:
      case AnnotationMode.crop:
        break;
    }
  }

  void _drawArrowHead(Canvas canvas, Paint paint, Offset from, Offset to) {
    final direction = to - from;
    if (direction.distance < 8) {
      return;
    }
    const headLength = 18.0;
    const headAngle = 0.55;
    final angle = direction.direction;
    final first = to - Offset.fromDirection(angle - headAngle, headLength);
    final second = to - Offset.fromDirection(angle + headAngle, headLength);
    if (arrowStyle == EditableArrowStyle.outline) {
      canvas
        ..drawLine(to, first, paint)
        ..drawLine(to, second, paint);
      return;
    }
    final headPath = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(first.dx, first.dy)
      ..lineTo(second.dx, second.dy)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  Rect _rectFromPoints(Offset start, Offset end) {
    return Rect.fromLTRB(
      start.dx < end.dx ? start.dx : end.dx,
      start.dy < end.dy ? start.dy : end.dy,
      start.dx > end.dx ? start.dx : end.dx,
      start.dy > end.dy ? start.dy : end.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _ShapeDraftPainter oldDelegate) {
    return start != oldDelegate.start ||
        end != oldDelegate.end ||
        mode != oldDelegate.mode ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        arrowStyle != oldDelegate.arrowStyle;
  }
}
