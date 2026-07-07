import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../widgets/image_editor_scaffold.dart';
import 'annotation_controller.dart';

/// 图片编辑页，提供选图、第三方画布编辑、马赛克涂抹和保存到相册。
///
/// 构建设计：页面复用统一编辑骨架，画布区只承载可编辑图片；工具模式放入
/// 标签栏，文本、颜色、粗细和图层变换放入属性面板。导出、历史记录和
/// 异常处理仍由控制器负责，避免改变业务逻辑。
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
        previewBorderRadius: 10,
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
        ],
      );
    });
  }
}

class _AnnotationCanvasFrame extends StatelessWidget {
  const _AnnotationCanvasFrame({required this.controller, required this.image});

  final AnnotationController controller;
  final LocalImageFile image;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = image.hasValidDimensions
        ? image.width / image.height
        : 1.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 560),
      child: AspectRatio(
        aspectRatio: aspectRatio.clamp(0.35, 2.4),
        child: _EditableCanvas(controller: controller),
      ),
    );
  }
}

class _EditableCanvas extends StatefulWidget {
  const _EditableCanvas({required this.controller});

  final AnnotationController controller;

  @override
  State<_EditableCanvas> createState() => _EditableCanvasState();
}

class _EditableCanvasState extends State<_EditableCanvas> {
  final List<Offset> _draftPoints = <Offset>[];

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

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterPainter.builder(
                  controller: controller.painterController,
                  onSelectedObjectDrawableChanged: controller.selectObject,
                  builder: (context, painter) => painter,
                ),
                Obx(() {
                  if (controller.mode.value != AnnotationMode.mosaic) {
                    return IgnorePointer(
                      child: CustomPaint(
                        painter: _MosaicPainter(
                          strokes: controller.strokes,
                          draftPoints: const [],
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
                        draftWidth: controller.strokeWidth.value.toDouble(),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startMosaic(DragStartDetails details) {
    setState(() {
      _draftPoints
        ..clear()
        ..add(details.localPosition);
    });
  }

  void _appendMosaic(DragUpdateDetails details) {
    setState(() => _draftPoints.add(details.localPosition));
  }

  void _finishMosaic(DragEndDetails details) {
    controller.addMosaicStroke(_draftPoints);
    setState(_draftPoints.clear);
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
              icon: Icons.pan_tool_alt_outlined,
              label: AnnotationMode.select.label,
              selected: controller.mode.value == AnnotationMode.select,
              onTap: () => controller.setMode(AnnotationMode.select),
            ),
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
              onTap: () => controller.setMode(AnnotationMode.text),
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
          ],
        ),
      ),
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
        _ShapeToolPanel(controller: controller),
        _LayerControls(controller: controller),
        _StrokeStyleControls(controller: controller),
      ],
    );
  }
}

class _ShapeToolPanel extends StatelessWidget {
  const _ShapeToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final layerType = switch (controller.mode.value) {
        AnnotationMode.rectangle => EditableLayerType.rectangle,
        AnnotationMode.circle => EditableLayerType.circle,
        AnnotationMode.arrow => EditableLayerType.arrow,
        _ => null,
      };
      if (layerType == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FilledButton.icon(
          onPressed: controller.selectedImage.value == null
              ? null
              : () => controller.addShapeLayer(layerType),
          icon: const Icon(Icons.add),
          label: Text('annotation.action.addLayer'.tr),
        ),
      );
    });
  }
}

class _LayerControls extends StatelessWidget {
  const _LayerControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final layer = controller.selectedObject.value;
      if (layer == null) {
        return const SizedBox.shrink();
      }
      final degrees = layer.rotationAngle * 180 / math.pi;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'annotation.layer.transform'.tr,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.zoom_out_map, size: 18),
                Expanded(
                  child: Slider(
                    value: layer.scale.clamp(0.4, 3.0),
                    min: 0.4,
                    max: 3,
                    divisions: 26,
                    label: '${(layer.scale * 100).round()}%',
                    onChanged: controller.updateSelectedObjectScale,
                  ),
                ),
                const Icon(Icons.rotate_90_degrees_ccw, size: 18),
                Expanded(
                  child: Slider(
                    value: degrees.clamp(-180, 180),
                    min: -180,
                    max: 180,
                    divisions: 36,
                    label: '${degrees.round()}°',
                    onChanged: controller.updateSelectedObjectRotation,
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

class _TextToolPanel extends StatelessWidget {
  const _TextToolPanel({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value != AnnotationMode.text) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.textController,
                maxLength: 40,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'annotation.text.label'.tr,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: controller.addTextLayer,
              icon: const Icon(Icons.add),
              label: Text('annotation.action.addText'.tr),
            ),
          ],
        ),
      );
    });
  }
}

class _StrokeStyleControls extends StatelessWidget {
  const _StrokeStyleControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedColor = controller.color.value;
      final strokeWidth = controller.strokeWidth.value;
      final showControls = switch (controller.mode.value) {
        AnnotationMode.brush ||
        AnnotationMode.mosaic ||
        AnnotationMode.rectangle ||
        AnnotationMode.circle ||
        AnnotationMode.arrow ||
        AnnotationMode.text => true,
        AnnotationMode.select => controller.selectedObject.value != null,
      };
      if (!showControls) {
        return const SizedBox.shrink();
      }
      return Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'annotation.strokeWidth'.trParams({
              'value': strokeWidth.toString(),
            }),
          ),
          SizedBox(
            width: 120,
            child: Slider(
              value: strokeWidth.toDouble(),
              min: 2,
              max: 60,
              divisions: 29,
              onChanged: controller.updateStrokeWidth,
            ),
          ),
        ],
      );
    });
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

class _MosaicPainter extends CustomPainter {
  const _MosaicPainter({
    required this.strokes,
    required this.draftPoints,
    required this.draftWidth,
  });

  final List<DrawingStroke> strokes;
  final List<Offset> draftPoints;
  final double draftWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    for (final stroke in strokes) {
      _paintPoints(canvas, paint, stroke.points, stroke.width);
    }
    _paintPoints(canvas, paint, draftPoints, draftWidth);
  }

  void _paintPoints(
    Canvas canvas,
    Paint paint,
    List<Offset> points,
    double width,
  ) {
    for (final point in points) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: width * 1.8, height: width * 1.8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MosaicPainter oldDelegate) {
    return true;
  }
}
