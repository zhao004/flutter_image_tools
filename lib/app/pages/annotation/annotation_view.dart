import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import 'annotation_controller.dart';

/// 图片编辑页，提供选图、图层编辑、涂抹和导出能力。
///
/// 构建设计：主体是可截图的编辑画布，底部工具栏承载模式切换；文字、
/// 形状和箭头以图层呈现，可移动、旋转和缩放，画笔和马赛克通过手势绘制。
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
              tooltip: 'annotation.action.export'.tr,
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

class _EditorStage extends StatefulWidget {
  const _EditorStage({required this.controller});

  final AnnotationController controller;

  @override
  State<_EditorStage> createState() => _EditorStageState();
}

class _EditorStageState extends State<_EditorStage> {
  final List<Offset> _draftPoints = <Offset>[];

  AnnotationController get controller => widget.controller;

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
                  child: _EditableCanvas(
                    controller: controller,
                    image: image,
                    draftPoints: _draftPoints,
                    onPanStart: _startStroke,
                    onPanUpdate: _appendStroke,
                    onPanEnd: _finishStroke,
                  ),
                ),
              ),
            ),
            _ResultText(controller: controller),
          ],
        ),
      );
    });
  }

  void _startStroke(DragStartDetails details) {
    final mode = controller.mode.value;
    if (mode != AnnotationMode.brush && mode != AnnotationMode.mosaic) {
      return;
    }
    setState(() {
      _draftPoints
        ..clear()
        ..add(details.localPosition);
    });
  }

  void _appendStroke(DragUpdateDetails details) {
    final mode = controller.mode.value;
    if (mode != AnnotationMode.brush && mode != AnnotationMode.mosaic) {
      return;
    }
    setState(() => _draftPoints.add(details.localPosition));
  }

  void _finishStroke(DragEndDetails details) {
    final mode = controller.mode.value;
    if (mode != AnnotationMode.brush && mode != AnnotationMode.mosaic) {
      return;
    }
    controller.addStroke(strokeMode: mode, points: _draftPoints);
    setState(_draftPoints.clear);
  }
}

class _EditableCanvas extends StatelessWidget {
  const _EditableCanvas({
    required this.controller,
    required this.image,
    required this.draftPoints,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final AnnotationController controller;
  final LocalImageFile image;
  final List<Offset> draftPoints;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: RepaintBoundary(
            key: controller.canvasKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(image.path), fit: BoxFit.cover),
                Obx(
                  () => CustomPaint(
                    painter: _StrokePainter(
                      strokes: controller.strokes,
                      draftMode: controller.mode.value,
                      draftColor: controller.color.value.color,
                      draftWidth: controller.strokeWidth.value.toDouble(),
                      draftPoints: draftPoints,
                    ),
                  ),
                ),
                Obx(
                  () => Stack(
                    fit: StackFit.expand,
                    children: controller.layers
                        .map(
                          (layer) => _EditableLayerWidget(
                            layer: layer,
                            isSelected:
                                controller.selectedLayerId.value == layer.id,
                            onTap: () => controller.selectLayer(layer.id),
                            onMove: controller.moveSelectedLayer,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableLayerWidget extends StatelessWidget {
  const _EditableLayerWidget({
    required this.layer,
    required this.isSelected,
    required this.onTap,
    required this.onMove,
  });

  final EditableLayer layer;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: layer.position,
        child: Transform.rotate(
          angle: degreesToRadians(layer.rotation),
          child: Transform.scale(
            scale: layer.scale,
            child: GestureDetector(
              onTap: onTap,
              onPanStart: (_) => onTap(),
              onPanUpdate: (details) => onMove(details.delta),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: _LayerShape(layer: layer),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerShape extends StatelessWidget {
  const _LayerShape({required this.layer});

  final EditableLayer layer;

  @override
  Widget build(BuildContext context) {
    return switch (layer.type) {
      EditableLayerType.text => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          layer.text,
          style: TextStyle(
            color: layer.color,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
        ),
      ),
      EditableLayerType.rectangle => CustomPaint(
        size: const Size(128, 86),
        painter: _ShapeLayerPainter(layer: layer),
      ),
      EditableLayerType.circle => CustomPaint(
        size: const Size(112, 112),
        painter: _ShapeLayerPainter(layer: layer),
      ),
      EditableLayerType.arrow => CustomPaint(
        size: const Size(140, 86),
        painter: _ShapeLayerPainter(layer: layer),
      ),
    };
  }
}

class _LayerControls extends StatelessWidget {
  const _LayerControls({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final layer = controller.selectedLayer;
      if (layer == null) {
        return const SizedBox.shrink();
      }
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                    onPressed: controller.deleteSelectedLayer,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.zoom_out_map, size: 18),
                  Expanded(
                    child: Slider(
                      value: layer.scale,
                      min: 0.4,
                      max: 3,
                      divisions: 26,
                      label: '${(layer.scale * 100).round()}%',
                      onChanged: controller.updateSelectedLayerScale,
                    ),
                  ),
                  const Icon(Icons.rotate_90_degrees_ccw, size: 18),
                  Expanded(
                    child: Slider(
                      value: layer.rotation,
                      min: -180,
                      max: 180,
                      divisions: 36,
                      label: '${layer.rotation.round()}°',
                      onChanged: controller.updateSelectedLayerRotation,
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

class _StrokePainter extends CustomPainter {
  const _StrokePainter({
    required this.strokes,
    required this.draftMode,
    required this.draftColor,
    required this.draftWidth,
    required this.draftPoints,
  });

  final List<DrawingStroke> strokes;
  final AnnotationMode draftMode;
  final Color draftColor;
  final double draftWidth;
  final List<Offset> draftPoints;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(
        canvas,
        stroke.mode,
        stroke.color,
        stroke.width,
        stroke.points,
      );
    }
    if (draftPoints.length >= 2) {
      _paintStroke(canvas, draftMode, draftColor, draftWidth, draftPoints);
    }
  }

  void _paintStroke(
    Canvas canvas,
    AnnotationMode mode,
    Color color,
    double width,
    List<Offset> points,
  ) {
    if (mode == AnnotationMode.mosaic) {
      final paint = Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
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
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return true;
  }
}

class _ShapeLayerPainter extends CustomPainter {
  const _ShapeLayerPainter({required this.layer});

  final EditableLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = layer.color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (layer.type) {
      case EditableLayerType.rectangle:
        canvas.drawRect(Offset.zero & size, paint);
      case EditableLayerType.circle:
        canvas.drawOval(Offset.zero & size, paint);
      case EditableLayerType.arrow:
        final start = Offset(8, size.height - 10);
        final end = Offset(size.width - 8, 10);
        canvas.drawLine(start, end, paint);
        final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
        const headLength = 24.0;
        for (final direction in <double>[0.72, -0.72]) {
          canvas.drawLine(
            end,
            Offset(
              end.dx - headLength * math.cos(angle + direction),
              end.dy - headLength * math.sin(angle + direction),
            ),
            paint,
          );
        }
      case EditableLayerType.text:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ShapeLayerPainter oldDelegate) {
    return oldDelegate.layer.color != layer.color ||
        oldDelegate.layer.type != layer.type;
  }
}
