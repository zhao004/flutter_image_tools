import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'image_watermark_controller.dart';

/// 图片水印编辑页：选择底图后在画布中实时预览水印图样式。
///
/// 设计意图：底图作为主编辑对象，水印图、位置和样式参数按组放入底部工具栏；
/// 右上角保存继续复用控制器的原生合成逻辑。
class ImageWatermarkView extends GetView<ImageWatermarkController> {
  const ImageWatermarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final watermark = controller.selectedWatermark.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'imageWatermark.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.layers_outlined,
        emptyTitle: 'imageWatermark.source.title'.tr,
        emptyMessage: 'imageWatermark.source.empty'.tr,
        pickLabel: 'imageWatermark.action.pickSource'.tr,
        repickLabel: 'imageWatermark.action.repickSource'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickSourceImage,
        onExport: watermark == null ? null : controller.addWatermark,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${watermark?.name ?? 'imageWatermark.watermark.empty'.tr}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          child: _ImageWatermarkOverlay(controller: controller),
        ),
        showPreviewInfo: false,
        expandPreviewToAvailableHeight: true,
        bottomToolbar: _ImageWatermarkBottomToolPanel(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'imageWatermark.result.title'.tr,
                detail:
                    '${controller.positionLabel(result.position)} · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }
}

class _ImageWatermarkOverlay extends StatelessWidget {
  const _ImageWatermarkOverlay({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final watermark = controller.selectedWatermark.value;
      if (watermark == null) {
        return const SizedBox.shrink();
      }
      final logo = Opacity(
        opacity: controller.opacity.value / 100,
        child: Transform.rotate(
          angle: controller.rotationDegrees.value * math.pi / 180,
          child: Image.file(
            File(watermark.path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return EditorImageLoadError(imageName: watermark.name);
            },
          ),
        ),
      );
      final size = 220.0 * controller.scalePercent.value / 100;
      final constrainedLogo = SizedBox.square(
        dimension: size.clamp(36, 220),
        child: logo,
      );
      if (controller.position.value == ImageWatermarkPosition.tile) {
        return IgnorePointer(
          child: _DiagonalImageWatermarkTile(
            key: const ValueKey('image-watermark-tile-layer'),
            watermark: constrainedLogo,
            tileSize: size.clamp(36, 220).toDouble(),
            spacing: controller.spacing.value.toDouble(),
          ),
        );
      }
      return IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Align(
            alignment: _alignmentFor(controller.position.value),
            child: constrainedLogo,
          ),
        ),
      );
    });
  }

  Alignment _alignmentFor(ImageWatermarkPosition position) {
    switch (position) {
      case ImageWatermarkPosition.topLeft:
        return Alignment.topLeft;
      case ImageWatermarkPosition.topRight:
        return Alignment.topRight;
      case ImageWatermarkPosition.bottomLeft:
        return Alignment.bottomLeft;
      case ImageWatermarkPosition.bottomRight:
        return Alignment.bottomRight;
      case ImageWatermarkPosition.center:
      case ImageWatermarkPosition.tile:
        return Alignment.center;
    }
  }
}

class _DiagonalImageWatermarkTile extends StatelessWidget {
  const _DiagonalImageWatermarkTile({
    super.key,
    required this.watermark,
    required this.tileSize,
    required this.spacing,
  });

  static const double _tileRotationRadians = -math.pi / 6;
  static const double _minimumTileGap = 8;

  final Widget watermark;
  final double tileSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safeWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final safeHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final safeSpacing = spacing.clamp(_minimumTileGap, 160.0);
          final stride = tileSize + safeSpacing;
          final expandedWidth = safeWidth + safeHeight;
          final expandedHeight = safeWidth + safeHeight;
          final columnCount = (expandedWidth / stride).ceil() + 4;
          final rowCount = (expandedHeight / stride).ceil() + 4;
          final originLeft = (expandedWidth - columnCount * stride) / 2;
          final originTop = (expandedHeight - rowCount * stride) / 2;

          return Transform.rotate(
            angle: _tileRotationRadians,
            child: OverflowBox(
              minWidth: expandedWidth,
              maxWidth: expandedWidth,
              minHeight: expandedHeight,
              maxHeight: expandedHeight,
              child: SizedBox(
                width: expandedWidth,
                height: expandedHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
                      for (
                        var columnIndex = 0;
                        columnIndex < columnCount;
                        columnIndex++
                      )
                        Positioned(
                          left:
                              originLeft +
                              columnIndex * stride +
                              (rowIndex.isOdd ? stride / 2 : 0),
                          top: originTop + rowIndex * stride,
                          width: stride,
                          height: stride,
                          child: Center(child: watermark),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageWatermarkBottomToolPanel extends StatefulWidget {
  const _ImageWatermarkBottomToolPanel({required this.controller});

  final ImageWatermarkController controller;

  @override
  State<_ImageWatermarkBottomToolPanel> createState() =>
      _ImageWatermarkBottomToolPanelState();
}

class _ImageWatermarkBottomToolPanelState
    extends State<_ImageWatermarkBottomToolPanel> {
  String _activeCategoryId = 'source';

  @override
  Widget build(BuildContext context) {
    final categories = [
      ToolCategory(
        id: 'source',
        name: 'imageWatermark.group.source'.tr,
        icon: Icons.add_photo_alternate_outlined,
      ),
      ToolCategory(
        id: 'position',
        name: 'imageWatermark.group.position'.tr,
        icon: Icons.open_with_outlined,
      ),
      ToolCategory(
        id: 'style',
        name: 'imageWatermark.group.style'.tr,
        icon: Icons.tune_outlined,
      ),
    ];
    return EditorDynamicToolPanel(
      categories: categories,
      activeCategoryId: _activeCategoryId,
      onCategorySelected: (category) {
        FocusScope.of(context).unfocus();
        setState(() => _activeCategoryId = category.id);
      },
      activePanel: _panelForCategory(_activeCategoryId),
      maxPanelHeight: 128,
      showPanelHeader: false,
    );
  }

  Widget _panelForCategory(String categoryId) {
    return switch (categoryId) {
      'position' => _ImageWatermarkPositionPanel(controller: widget.controller),
      'style' => _ImageWatermarkStylePanel(controller: widget.controller),
      _ => _ImageWatermarkSourcePanel(controller: widget.controller),
    };
  }
}

class _ImageWatermarkSourcePanel extends StatelessWidget {
  const _ImageWatermarkSourcePanel({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final watermark = controller.selectedWatermark.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.pickWatermarkImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                watermark == null
                    ? 'imageWatermark.action.pickWatermark'.tr
                    : 'imageWatermark.action.repickWatermark'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (watermark != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: Text(
                  watermark.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (controller.tasks.isNotEmpty) ...[
              const SizedBox(width: 16),
              _ImageWatermarkProgressIndicator(controller: controller),
            ],
          ],
        ),
      );
    });
  }
}

class _ImageWatermarkPositionPanel extends StatelessWidget {
  const _ImageWatermarkPositionPanel({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: EditorOptionWrap<ImageWatermarkPosition>(
          values: ImageWatermarkPosition.values,
          selected: controller.position.value,
          labelFor: (value) => value.labelKey.tr,
          enabled: !controller.isBusy.value,
          onSelected: controller.setPosition,
        ),
      );
    });
  }
}

class _ImageWatermarkStylePanel extends StatelessWidget {
  const _ImageWatermarkStylePanel({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ImageWatermarkSlider(
              label: 'imageWatermark.config.opacity'.trParams({
                'opacity': '${controller.opacity.value}',
              }),
              value: controller.opacity.value.toDouble(),
              min: 10,
              max: 100,
              divisions: 18,
              enabled: !controller.isBusy.value,
              onChanged: controller.updateOpacity,
            ),
            const SizedBox(width: 16),
            _ImageWatermarkSlider(
              label: 'imageWatermark.config.scale'.trParams({
                'scale': '${controller.scalePercent.value}',
              }),
              value: controller.scalePercent.value.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              enabled: !controller.isBusy.value,
              onChanged: controller.updateScale,
            ),
            const SizedBox(width: 16),
            _ImageWatermarkSlider(
              label: 'imageWatermark.config.spacing'.trParams({
                'spacing': '${controller.spacing.value}',
              }),
              value: controller.spacing.value.toDouble(),
              min: 8,
              max: 160,
              divisions: 38,
              enabled: !controller.isBusy.value,
              onChanged: controller.updateSpacing,
            ),
            const SizedBox(width: 16),
            _ImageWatermarkSlider(
              label: 'imageWatermark.config.rotation'.trParams({
                'rotation': '${controller.rotationDegrees.value}',
              }),
              value: controller.rotationDegrees.value.toDouble(),
              min: -180,
              max: 180,
              divisions: 72,
              enabled: !controller.isBusy.value,
              onChanged: controller.updateRotation,
            ),
            if (controller.tasks.isNotEmpty) ...[
              const SizedBox(width: 16),
              _ImageWatermarkProgressIndicator(controller: controller),
            ],
          ],
        ),
      );
    });
  }
}

class _ImageWatermarkProgressIndicator extends StatelessWidget {
  const _ImageWatermarkProgressIndicator({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 4),
          Text(
            'imageWatermark.progress.processed'.trParams({
              'processed': '${controller.processedCount.value}',
              'total': '${controller.selectedImages.length}',
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ImageWatermarkSlider extends StatelessWidget {
  const _ImageWatermarkSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
