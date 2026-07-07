import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../widgets/image_editor_scaffold.dart';
import 'grid_controller.dart';

/// 九宫格切图页，选图后进入可拖动网格编辑状态。
///
/// 构建设计：页面复用统一编辑骨架，将网格预览放入画布区，网格尺寸与
/// 缩放放入属性面板，居中和导出放入底部动作栏。业务处理仍由控制器完成，
/// 页面只负责展示与手势转发，避免改变原有切图参数和历史记录逻辑。
class GridView extends GetView<GridController> {
  const GridView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'grid.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.grid_on_outlined,
        emptyTitle: 'grid.image.title'.tr,
        emptyMessage: 'grid.image.empty'.tr,
        pickLabel: 'grid.action.pickImage'.tr,
        repickLabel: 'grid.action.repickImage'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.ios_share_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.splitImage,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${controller.formatBytes(image.sizeBytes)}',
        lockPreviewScroll: true,
        previewBuilder: (context, previewImage) =>
            _GridEditorCanvas(controller: controller, image: previewImage),
        tabBar: _GridToolTabs(controller: controller),
        toolbar: _GridPropertyPanel(controller: controller),
        bottomToolbar: _GridActionToolbar(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'grid.result.title'.tr,
                detail:
                    '${'grid.result.pieceCount'.trParams({'count': '${result.pieceCount}'})} · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputDirectory,
              ),
      );
    });
  }
}

class _GridEditorCanvas extends StatefulWidget {
  const _GridEditorCanvas({required this.controller, required this.image});

  final GridController controller;
  final LocalImageFile image;

  @override
  State<_GridEditorCanvas> createState() => _GridEditorCanvasState();
}

class _GridEditorCanvasState extends State<_GridEditorCanvas> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = _previewSizeFor(widget.image, constraints);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.controller.updateCanvasSize(previewSize);
          }
        });
        return SizedBox(
          width: previewSize.width,
          height: previewSize.height,
          child: _GridPreviewCanvas(
            controller: widget.controller,
            image: widget.image,
            canvasSize: previewSize,
          ),
        );
      },
    );
  }

  Size _previewSizeFor(LocalImageFile image, BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth.clamp(180.0, 900.0);
    final maxHeight = constraints.maxHeight.clamp(180.0, 560.0);
    final imageWidth = image.width > 0 ? image.width.toDouble() : 1.0;
    final imageHeight = image.height > 0 ? image.height.toDouble() : 1.0;
    final aspectRatio = imageWidth / imageHeight;
    var width = maxWidth.toDouble();
    var height = width / aspectRatio;
    if (height > maxHeight) {
      height = maxHeight.toDouble();
      width = height * aspectRatio;
    }
    return Size(width, height);
  }
}

class _GridPreviewCanvas extends StatelessWidget {
  const _GridPreviewCanvas({
    required this.controller,
    required this.image,
    required this.canvasSize,
  });

  final GridController controller;
  final LocalImageFile image;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(image.path), fit: BoxFit.fill),
            ColoredBox(color: Colors.black.withValues(alpha: 0.10)),
            Obx(() {
              final gridRect = controller.gridRectFor(canvasSize);
              return Positioned.fromRect(
                rect: gridRect,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: controller.isBusy.value
                      ? null
                      : (details) =>
                            controller.moveGrid(details.delta, canvasSize),
                  child: CustomPaint(
                    painter: _GridOverlayPainter(
                      gridSize: controller.gridSize.value,
                      color: colorScheme.primary,
                    ),
                    child: const _GridDragHandle(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GridDragHandle extends StatelessWidget {
  const _GridDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_with, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                'grid.editor.drag'.tr,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridOverlayPainter extends CustomPainter {
  const _GridOverlayPainter({required this.gridSize, required this.color});

  final int gridSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 1.2;

    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawRect(Offset.zero & size, borderPaint);
    for (var index = 1; index < gridSize; index += 1) {
      final position = size.width * index / gridSize;
      canvas.drawLine(
        Offset(position, 0),
        Offset(position, size.height),
        linePaint,
      );
      canvas.drawLine(
        Offset(0, position),
        Offset(size.width, position),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridOverlayPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize || oldDelegate.color != color;
  }
}

class _GridToolTabs extends StatelessWidget {
  const _GridToolTabs({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text('grid.editor.scale'.tr),
              selected: true,
              onSelected: controller.isBusy.value ? null : (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPropertyPanel extends StatelessWidget {
  const _GridPropertyPanel({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasImage = controller.selectedImage.value != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'grid.editor.hint'.tr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _GridSizeSelector(controller: controller),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('grid.editor.scale'.tr),
              Expanded(
                child: Slider(
                  value: controller.gridScale.value,
                  min: GridController.minGridScale,
                  max: GridController.maxGridScale,
                  divisions: 13,
                  onChanged: hasImage && !controller.isBusy.value
                      ? (value) => controller.setGridScale(
                          value,
                          controller.canvasSize.value,
                        )
                      : null,
                ),
              ),
              Text('${(controller.gridScale.value * 100).round()}%'),
            ],
          ),
        ],
      );
    });
  }
}

class _GridActionToolbar extends StatelessWidget {
  const _GridActionToolbar({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasImage = controller.selectedImage.value != null;
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: hasImage && !controller.isBusy.value
                ? controller.resetGridPosition
                : null,
            icon: const Icon(Icons.center_focus_strong_outlined),
            label: Text('grid.action.centerGrid'.tr),
          ),
        ],
      );
    });
  }
}

class _GridSizeSelector extends StatelessWidget {
  const _GridSizeSelector({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment<int>(value: 2, label: Text('2 × 2')),
        ButtonSegment<int>(value: 3, label: Text('3 × 3')),
        ButtonSegment<int>(value: 4, label: Text('4 × 4')),
        ButtonSegment<int>(value: 5, label: Text('5 × 5')),
      ],
      selected: {controller.gridSize.value},
      showSelectedIcon: false,
      onSelectionChanged: controller.isBusy.value
          ? null
          : (values) => controller.setGridSize(values.first),
    );
  }
}
