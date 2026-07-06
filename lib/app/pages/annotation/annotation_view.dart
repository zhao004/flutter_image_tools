import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import 'annotation_controller.dart';

/// 图片编辑页，提供选图、第三方画布编辑、马赛克涂抹和保存到相册。
///
/// 构建设计：预览区使用 `flutter_painter_v2` 承载文字、形状、箭头和画笔；
/// 底部工具栏保持单图编辑流程，马赛克作为覆盖层处理，避免引入额外原生依赖。
class AnnotationView extends GetView<AnnotationController> {
  const AnnotationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('annotation.title'.tr),
        actions: [
          Obx(
            () => controller.selectedImage.value == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'annotation.action.repickImage'.tr,
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
          ),
          Obx(
            () => IconButton(
              tooltip: 'common.saveToGallery'.tr,
              onPressed: controller.isBusy.value
                  ? null
                  : controller.exportEditedImage,
              icon: controller.isBusy.value
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _EditorStage(controller: controller)),
            _LayerControls(controller: controller),
            _BottomToolbar(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _EditorStage extends StatelessWidget {
  const _EditorStage({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      if (image == null) {
        return _EmptyEditor(controller: controller);
      }

      final aspectRatio = image.hasValidDimensions
          ? image.width / image.height
          : 1.0;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _ImageInfo(controller: controller, image: image),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio.clamp(0.35, 2.4),
                  child: _EditableCanvas(controller: controller),
                ),
              ),
            ),
            _ResultText(controller: controller),
          ],
        ),
      );
    });
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
          controller.updateCanvasSize(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
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
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'annotation.layer.transform'.tr,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'annotation.action.deleteLayer'.tr,
                    onPressed: controller.deleteSelectedObject,
                    icon: const Icon(Icons.delete_outline),
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
        ),
      );
    });
  }
}

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TextInputRow(controller: controller),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ToolButton(
                              icon: Icons.pan_tool_alt_outlined,
                              label: AnnotationMode.select.label,
                              selected:
                                  controller.mode.value ==
                                  AnnotationMode.select,
                              onTap: () =>
                                  controller.setMode(AnnotationMode.select),
                            ),
                            _ToolButton(
                              icon: Icons.brush_outlined,
                              label: AnnotationMode.brush.label,
                              selected:
                                  controller.mode.value == AnnotationMode.brush,
                              onTap: () =>
                                  controller.setMode(AnnotationMode.brush),
                            ),
                            _ToolButton(
                              icon: Icons.grid_on_outlined,
                              label: AnnotationMode.mosaic.label,
                              selected:
                                  controller.mode.value ==
                                  AnnotationMode.mosaic,
                              onTap: () =>
                                  controller.setMode(AnnotationMode.mosaic),
                            ),
                            _ToolButton(
                              icon: Icons.text_fields,
                              label: AnnotationMode.text.label,
                              selected:
                                  controller.mode.value == AnnotationMode.text,
                              onTap: () =>
                                  controller.setMode(AnnotationMode.text),
                            ),
                            _ToolButton(
                              icon: Icons.crop_square,
                              label: AnnotationMode.rectangle.label,
                              selected: false,
                              onTap: () => controller.addShapeLayer(
                                EditableLayerType.rectangle,
                              ),
                            ),
                            _ToolButton(
                              icon: Icons.circle_outlined,
                              label: AnnotationMode.circle.label,
                              selected: false,
                              onTap: () => controller.addShapeLayer(
                                EditableLayerType.circle,
                              ),
                            ),
                            _ToolButton(
                              icon: Icons.arrow_forward,
                              label: AnnotationMode.arrow.label,
                              selected: false,
                              onTap: () => controller.addShapeLayer(
                                EditableLayerType.arrow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'annotation.action.undo'.tr,
                      onPressed: controller.hasEdits ? controller.undo : null,
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      tooltip: 'annotation.action.clear'.tr,
                      onPressed: controller.hasEdits
                          ? () => controller.clearEdits()
                          : null,
                      icon: const Icon(Icons.layers_clear_outlined),
                    ),
                  ],
                ),
                _StyleControls(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextInputRow extends StatelessWidget {
  const _TextInputRow({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.mode.value != AnnotationMode.text) {
      return const SizedBox.shrink();
    }
    return Row(
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
    );
  }
}

class _StyleControls extends StatelessWidget {
  const _StyleControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
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
                        selected: controller.color.value == item,
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
            'value': controller.strokeWidth.value.toString(),
          }),
        ),
        SizedBox(
          width: 120,
          child: Slider(
            value: controller.strokeWidth.value.toDouble(),
            min: 2,
            max: 60,
            divisions: 29,
            onChanged: controller.updateStrokeWidth,
          ),
        ),
      ],
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

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'annotation.image.empty'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: controller.pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text('annotation.action.pickImage'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageInfo extends StatelessWidget {
  const _ImageInfo({required this.controller, required this.image});

  final AnnotationController controller;
  final LocalImageFile image;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.image_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text(controller.formatDimensions(image)),
      ],
    );
  }
}

class _ResultText extends StatelessWidget {
  const _ResultText({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const SizedBox(height: 8);
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '${'annotation.result.outputSize'.trParams({'size': controller.formatBytes(result.outputSizeBytes)})} · ${result.outputPath}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    });
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
