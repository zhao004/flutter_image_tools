import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../utils/watermark_layout.dart';
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
          overlayBuilder: (context, previewSize) => _ImageWatermarkOverlay(
            controller: controller,
            image: previewImage,
            previewSize: previewSize,
          ),
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
  const _ImageWatermarkOverlay({
    required this.controller,
    required this.image,
    required this.previewSize,
  });

  final ImageWatermarkController controller;
  final LocalImageFile image;
  final Size previewSize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final watermark = controller.selectedWatermark.value;
      if (watermark == null) {
        return const SizedBox.shrink();
      }
      final outputSize = WatermarkLayout.imageWatermarkOutputSize(
        sourceWidth: image.width.toDouble(),
        sourceHeight: image.height.toDouble(),
        watermarkWidth: watermark.width.toDouble(),
        watermarkHeight: watermark.height.toDouble(),
        scalePercent: controller.scalePercent.value,
      );
      final roundedOutputSize = WatermarkSize(
        width: outputSize.roundedWidth.toDouble(),
        height: outputSize.roundedHeight.toDouble(),
      );
      final transformedOutputSize = WatermarkLayout.rotatedOutputSize(
        width: roundedOutputSize.width,
        height: roundedOutputSize.height,
        rotationDegrees: controller.rotationDegrees.value,
      );
      final previewScale = WatermarkLayout.previewScale(
        sourceWidth: image.width.toDouble(),
        sourceHeight: image.height.toDouble(),
        previewWidth: previewSize.width,
        previewHeight: previewSize.height,
      );
      if (controller.position.value == ImageWatermarkPosition.tile) {
        return IgnorePointer(
          child: _ImageWatermarkTilePreview(
            key: const ValueKey('image-watermark-tile-layer'),
            source: image,
            watermark: watermark,
            outputSize: roundedOutputSize,
            transformedOutputSize: transformedOutputSize,
            previewScale: previewScale,
            opacity: controller.opacity.value,
            spacing: controller.spacing.value,
            rotationDegrees: controller.rotationDegrees.value,
          ),
        );
      }
      final offset = WatermarkLayout.positionOffset(
        sourceWidth: image.width,
        sourceHeight: image.height,
        overlayWidth: transformedOutputSize.roundedWidth,
        overlayHeight: transformedOutputSize.roundedHeight,
        position: controller.position.value.value,
      );
      final renderedWidth = image.width * previewScale;
      final renderedHeight = image.height * previewScale;
      final originLeft = (previewSize.width - renderedWidth) / 2;
      final originTop = (previewSize.height - renderedHeight) / 2;
      return IgnorePointer(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: originLeft + offset.x * previewScale,
              top: originTop + offset.y * previewScale,
              child: _RotatedImageWatermark(
                key: const ValueKey('image-watermark-transformed-layer'),
                watermark: watermark,
                outputSize: roundedOutputSize,
                transformedOutputSize: transformedOutputSize,
                previewScale: previewScale,
                opacity: controller.opacity.value,
                rotationDegrees: controller.rotationDegrees.value,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// 按导出像素包围盒承载旋转水印，避免 Transform 只旋转绘制而不改变布局尺寸。
class _RotatedImageWatermark extends StatelessWidget {
  const _RotatedImageWatermark({
    super.key,
    required this.watermark,
    required this.outputSize,
    required this.transformedOutputSize,
    required this.previewScale,
    required this.opacity,
    required this.rotationDegrees,
  });

  final LocalImageFile watermark;
  final WatermarkSize outputSize;
  final WatermarkSize transformedOutputSize;
  final double previewScale;
  final int opacity;
  final int rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final outputWidth = outputSize.width * previewScale;
    final outputHeight = outputSize.height * previewScale;
    return Opacity(
      opacity: opacity.clamp(0, 100) / 100,
      child: SizedBox(
        width: transformedOutputSize.width * previewScale,
        height: transformedOutputSize.height * previewScale,
        child: OverflowBox(
          minWidth: outputWidth,
          maxWidth: outputWidth,
          minHeight: outputHeight,
          maxHeight: outputHeight,
          child: Transform.rotate(
            angle: rotationDegrees * math.pi / 180,
            child: SizedBox(
              width: outputWidth,
              height: outputHeight,
              child: Image.file(
                File(watermark.path),
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) {
                  return EditorImageLoadError(imageName: watermark.name);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 图片平铺预览直接复用导出层的画布尺寸、横纵步长和交错坐标。
class _ImageWatermarkTilePreview extends StatelessWidget {
  const _ImageWatermarkTilePreview({
    super.key,
    required this.source,
    required this.watermark,
    required this.outputSize,
    required this.transformedOutputSize,
    required this.previewScale,
    required this.opacity,
    required this.spacing,
    required this.rotationDegrees,
  });

  final LocalImageFile source;
  final LocalImageFile watermark;
  final WatermarkSize outputSize;
  final WatermarkSize transformedOutputSize;
  final double previewScale;
  final int opacity;
  final int spacing;
  final int rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final tileLayout = WatermarkLayout.tileOutputLayout(
      sourceWidth: source.width,
      sourceHeight: source.height,
      overlayWidth: transformedOutputSize.roundedWidth,
      overlayHeight: transformedOutputSize.roundedHeight,
      spacing: spacing,
    );
    final previewLayerSize = tileLayout.layerSize * previewScale;
    final previewOverlayWidth = transformedOutputSize.width * previewScale;
    final previewOverlayHeight = transformedOutputSize.height * previewScale;
    return ClipRect(
      child: Center(
        child: Transform.rotate(
          angle: WatermarkLayout.tileRotationDegrees * math.pi / 180,
          child: OverflowBox(
            minWidth: previewLayerSize,
            maxWidth: previewLayerSize,
            minHeight: previewLayerSize,
            maxHeight: previewLayerSize,
            child: SizedBox(
              width: previewLayerSize,
              height: previewLayerSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final offset in tileLayout.offsets)
                    Positioned(
                      left: offset.x * previewScale,
                      top: offset.y * previewScale,
                      width: previewOverlayWidth,
                      height: previewOverlayHeight,
                      child: _RotatedImageWatermark(
                        watermark: watermark,
                        outputSize: outputSize,
                        transformedOutputSize: transformedOutputSize,
                        previewScale: previewScale,
                        opacity: opacity,
                        rotationDegrees: rotationDegrees,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
            if (controller.position.value == ImageWatermarkPosition.tile) ...[
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
            ],
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
