import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/grid_image_file.dart';
import '../../models/local_image_file.dart';
import 'grid_controller.dart';

/// 九宫格切图页，选图后进入可拖动网格编辑状态。
///
/// 构建设计：主区域只承载图片预览和网格定位，底部工具栏集中处理网格
/// 数量、网格占比、居中和导出，避免用户在多个卡片之间来回跳转。
class GridView extends GetView<GridController> {
  const GridView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('grid.title'.tr),
        actions: [
          Obx(() {
            final hasImage = controller.selectedImage.value != null;
            return IconButton(
              tooltip: hasImage
                  ? 'grid.action.repickImage'.tr
                  : 'grid.action.pickImage'.tr,
              onPressed: controller.isBusy.value ? null : controller.pickImage,
              icon: Icon(
                hasImage
                    ? Icons.add_photo_alternate_outlined
                    : Icons.image_search_outlined,
              ),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _GridEditorStage(controller: controller)),
            _GridBottomToolbar(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _GridEditorStage extends StatefulWidget {
  const _GridEditorStage({required this.controller});

  final GridController controller;

  @override
  State<_GridEditorStage> createState() => _GridEditorStageState();
}

class _GridEditorStageState extends State<_GridEditorStage> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = widget.controller.selectedImage.value;
      if (image == null) {
        return _GridEmptyState(controller: widget.controller);
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final previewSize = _previewSizeFor(image, constraints);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.controller.updateCanvasSize(previewSize);
            }
          });
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SizedBox(
                      width: previewSize.width,
                      height: previewSize.height,
                      child: _GridPreviewCanvas(
                        controller: widget.controller,
                        image: image,
                        canvasSize: previewSize,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectedImageMeta(
                    controller: widget.controller,
                    image: image,
                  ),
                  _GridResultSummary(controller: widget.controller),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Size _previewSizeFor(LocalImageFile image, BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth - 32;
    final maxHeight = (constraints.maxHeight - 92).clamp(180.0, 720.0);
    final imageWidth = image.width > 0 ? image.width.toDouble() : 1.0;
    final imageHeight = image.height > 0 ? image.height.toDouble() : 1.0;
    final aspectRatio = imageWidth / imageHeight;
    var width = maxWidth.clamp(180.0, 900.0);
    var height = width / aspectRatio;
    if (height > maxHeight) {
      height = maxHeight;
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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

class _GridBottomToolbar extends StatelessWidget {
  const _GridBottomToolbar({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasImage = controller.selectedImage.value != null;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: hasImage && !controller.isBusy.value
                          ? controller.resetGridPosition
                          : null,
                      icon: const Icon(Icons.center_focus_strong_outlined),
                      label: Text('grid.action.centerGrid'.tr),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: hasImage && !controller.isBusy.value
                            ? controller.splitImage
                            : null,
                        icon: controller.isBusy.value
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.ios_share_outlined),
                        label: Text(
                          controller.isBusy.value
                              ? 'common.processing'.tr
                              : 'grid.action.split'.tr,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

class _GridEmptyState extends StatelessWidget {
  const _GridEmptyState({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_on_outlined,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'grid.image.title'.tr,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'grid.image.empty'.tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('grid.action.pickImage'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedImageMeta extends StatelessWidget {
  const _SelectedImageMeta({required this.controller, required this.image});

  final GridController controller;
  final LocalImageFile image;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          image.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${controller.formatDimensions(image)} · ${controller.formatBytes(image.sizeBytes)}',
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _GridResultSummary extends StatelessWidget {
  const _GridResultSummary({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _ResultPill(controller: controller, result: result),
      );
    });
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.controller, required this.result});

  final GridController controller;
  final GridImageFile result;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: result.outputDirectory,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '${'grid.result.title'.tr} · '
            '${'grid.result.pieceCount'.trParams({'count': '${result.pieceCount}'})} · '
            '${controller.formatBytes(result.outputSizeBytes)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
