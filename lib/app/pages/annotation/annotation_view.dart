import 'dart:math' as math;

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
        previewBorderRadius: 0,
        lockPreviewScroll: true,
        previewBuilder: (context, previewImage) =>
            _AnnotationCanvasFrame(controller: controller, image: previewImage),
        appBarActions: [_AnnotationTopActions(controller: controller)],
        tabBar: _AnnotationToolTabs(controller: controller),
        toolbar: _annotationToolbar(),
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

  Widget? _annotationToolbar() {
    final mode = controller.mode.value;
    final hasSelectedLayer = controller.selectedObject.value != null;
    if (mode == AnnotationMode.select && !hasSelectedLayer) {
      return null;
    }
    return _AnnotationPropertyPanel(controller: controller);
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
          if (selectedLayer != null)
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
                builder: (context, painter) => GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) => controller
                      .deselectSelectedObjectIfBlankTap(details.localPosition),
                  child: painter,
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
                        color: controller.color.value.color,
                        strokeWidth: controller.strokeWidth.value.toDouble(),
                        arrowStyle: controller.arrowStyle.value,
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
      final mode = controller.mode.value;
      final colorFilter = _colorFilterFor(controller.filter.value);
      if (!_isImageProcessingMode(mode)) {
        return ClipRect(
          key: const ValueKey('annotation-adjustment-preview'),
          child: colorFilter == null
              ? child
              : ColorFiltered(colorFilter: colorFilter, child: child),
        );
      }

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
        child: IgnorePointer(
          // 图片处理标签只负责预览全图变换；禁用画布命中避免缩放/旋转后的坐标反向映射影响标注交互。
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: preview,
          ),
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

class _AnnotationToolTabs extends StatelessWidget {
  const _AnnotationToolTabs({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolButton(
              icon: Icons.brush_outlined,
              label: AnnotationMode.brush.label,
              selected: controller.mode.value == AnnotationMode.brush,
              onTap: () => controller.setMode(AnnotationMode.brush),
            ),
            _ToolButton(
              icon: Icons.grid_on_outlined,
              label: AnnotationMode.mosaic.label,
              selected: controller.mode.value == AnnotationMode.mosaic,
              onTap: () => controller.setMode(AnnotationMode.mosaic),
            ),
            _ToolButton(
              icon: Icons.text_fields,
              label: AnnotationMode.text.label,
              selected: controller.mode.value == AnnotationMode.text,
              onTap: () async {
                controller.setMode(AnnotationMode.text);
                controller.createDefaultTextLayer();
                await _showTextEditor(context, controller);
              },
            ),
            _ToolButton(
              icon: Icons.crop_square,
              label: AnnotationMode.rectangle.label,
              selected: controller.mode.value == AnnotationMode.rectangle,
              onTap: () =>
                  controller.selectShapeTool(EditableLayerType.rectangle),
            ),
            _ToolButton(
              icon: Icons.circle_outlined,
              label: AnnotationMode.circle.label,
              selected: controller.mode.value == AnnotationMode.circle,
              onTap: () => controller.selectShapeTool(EditableLayerType.circle),
            ),
            _ToolButton(
              icon: Icons.arrow_forward,
              label: AnnotationMode.arrow.label,
              selected: controller.mode.value == AnnotationMode.arrow,
              onTap: () => controller.selectShapeTool(EditableLayerType.arrow),
            ),
            _ToolButton(
              icon: Icons.filter_vintage_outlined,
              label: AnnotationMode.filter.label,
              selected: controller.mode.value == AnnotationMode.filter,
              onTap: () => controller.setMode(AnnotationMode.filter),
            ),
            _ToolButton(
              icon: Icons.rotate_right,
              label: AnnotationMode.rotate.label,
              selected: controller.mode.value == AnnotationMode.rotate,
              onTap: () => controller.setMode(AnnotationMode.rotate),
            ),
            _ToolButton(
              icon: Icons.flip_outlined,
              label: AnnotationMode.flip.label,
              selected: controller.mode.value == AnnotationMode.flip,
              onTap: () => controller.setMode(AnnotationMode.flip),
            ),
            _ToolButton(
              icon: Icons.aspect_ratio_outlined,
              label: AnnotationMode.resize.label,
              selected: controller.mode.value == AnnotationMode.resize,
              onTap: () => controller.setMode(AnnotationMode.resize),
            ),
            _ToolButton(
              icon: Icons.crop_outlined,
              label: AnnotationMode.crop.label,
              selected: controller.mode.value == AnnotationMode.crop,
              onTap: () => controller.setMode(AnnotationMode.crop),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTextEditor(
    BuildContext context,
    AnnotationController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
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
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  if (controller.updateSelectedTextLayer()) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text('common.confirm'.tr),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnnotationPropertyPanel extends StatelessWidget {
  const _AnnotationPropertyPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TextToolPanel(controller: controller),
        _MosaicToolPanel(controller: controller),
        _FilterToolPanel(controller: controller),
        _RotateToolPanel(controller: controller),
        _FlipToolPanel(controller: controller),
        _ResizeToolPanel(controller: controller),
        _CropToolPanel(controller: controller),
        _ArrowStyleControls(controller: controller),
        _StrokeWidthControls(controller: controller),
        _ColorControls(controller: controller),
      ],
    );
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
        title: 'annotation.filter.title'.tr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
        title: 'annotation.rotate.title'.tr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
              ],
            ),
            Row(
              children: [
                Text('rotate.angle.custom'.trParams({'degrees': '$degrees'})),
                Expanded(
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
        title: 'flip.direction.title'.tr,
        child: Row(
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
      return _PanelBlock(
        title: 'resize.size.title'.tr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _DimensionField(
                    label: 'resize.size.width'.tr,
                    controller: controller.resizeWidthController,
                    onChanged: controller.updateResizeWidth,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DimensionField(
                    label: 'resize.size.height'.tr,
                    controller: controller.resizeHeightController,
                    onChanged: controller.updateResizeHeight,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('resize.size.keepAspectRatio'.tr),
                    value: controller.resizeKeepAspectRatio.value,
                    onChanged: (value) =>
                        controller.setResizeKeepAspectRatio(value ?? true),
                  ),
                ),
              ],
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
        title: 'annotation.crop.title'.tr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
        ),
      );
    });
  }
}

class _MosaicToolPanel extends StatelessWidget {
  const _MosaicToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value != AnnotationMode.mosaic) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<MosaicDrawMode>(
            segments: MosaicDrawMode.values
                .map(
                  (mode) => ButtonSegment<MosaicDrawMode>(
                    value: mode,
                    label: Text(mode.label),
                  ),
                )
                .toList(growable: false),
            selected: {controller.mosaicDrawMode.value},
            onSelectionChanged: (values) {
              if (values.isNotEmpty) {
                controller.setMosaicDrawMode(values.first);
              }
            },
          ),
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
        padding: const EdgeInsets.only(bottom: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
      if (controller.mode.value != AnnotationMode.text) {
        return const SizedBox.shrink();
      }
      return const SizedBox.shrink();
    });
  }
}

class _StrokeWidthControls extends StatelessWidget {
  const _StrokeWidthControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showControls = switch (controller.mode.value) {
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
      if (!showControls) {
        return const SizedBox.shrink();
      }
      final value = controller.strokeWidth.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text('annotation.strokeWidth'.trParams({'value': '$value'})),
            Expanded(
              child: Slider(
                min: 2,
                max: 60,
                divisions: 58,
                value: value.toDouble(),
                onChanged: controller.updateStrokeWidth,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ColorControls extends StatelessWidget {
  const _ColorControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedColor = controller.color.value;
      final showControls = switch (controller.mode.value) {
        AnnotationMode.brush ||
        AnnotationMode.rectangle ||
        AnnotationMode.circle ||
        AnnotationMode.arrow ||
        AnnotationMode.text => true,
        AnnotationMode.select => controller.selectedObject.value != null,
        AnnotationMode.mosaic ||
        AnnotationMode.filter ||
        AnnotationMode.rotate ||
        AnnotationMode.flip ||
        AnnotationMode.resize ||
        AnnotationMode.crop => false,
      };
      if (!showControls) {
        return const SizedBox.shrink();
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: AnnotationColor.values
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(item.label),
                    selected: selectedColor == item,
                    avatar: CircleAvatar(backgroundColor: item.color),
                    onSelected: (_) => controller.setColor(item),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      );
    });
  }
}

class _PanelBlock extends StatelessWidget {
  const _PanelBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
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
  });

  final List<DrawingStroke> strokes;
  final List<Offset> draftPoints;
  final MosaicStrokeKind draftKind;
  final double draftWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    for (final stroke in strokes) {
      _paintStroke(canvas, paint, stroke.kind, stroke.points, stroke.width);
    }
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
