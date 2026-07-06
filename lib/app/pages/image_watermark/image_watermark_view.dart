import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'image_watermark_controller.dart';

/// 图片水印编辑页：选择底图后在画布中实时预览水印图样式。
///
/// 设计意图：底图作为主编辑对象，水印图和样式参数集中在底部工具栏；
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
        exportLabel: 'imageWatermark.action.add'.tr,
        exportIcon: Icons.save_alt_outlined,
        onPickImage: controller.pickSourceImage,
        onExport: controller.addWatermark,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${watermark?.name ?? 'imageWatermark.watermark.empty'.tr}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          child: _ImageWatermarkOverlay(controller: controller),
        ),
        toolbar: _ImageWatermarkToolbar(controller: controller),
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
    final watermark = controller.selectedWatermark.value;
    if (watermark == null) {
      return const SizedBox.shrink();
    }
    final logo = Opacity(
      opacity: controller.opacity.value / 100,
      child: Transform.rotate(
        angle: controller.rotationDegrees.value * math.pi / 180,
        child: Image.file(File(watermark.path), fit: BoxFit.contain),
      ),
    );
    final size = 220.0 * controller.scalePercent.value / 100;
    final constrainedLogo = SizedBox.square(
      dimension: size.clamp(36, 220),
      child: logo,
    );
    if (controller.position.value == ImageWatermarkPosition.tile) {
      return IgnorePointer(
        child: Wrap(
          spacing: 32,
          runSpacing: 24,
          children: List.generate(18, (_) => constrainedLogo),
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

class _ImageWatermarkToolbar extends StatelessWidget {
  const _ImageWatermarkToolbar({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    final watermark = controller.selectedWatermark.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'imageWatermark.config.title'.tr,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: controller.isBusy.value
                  ? null
                  : controller.pickWatermarkImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                watermark == null
                    ? 'imageWatermark.action.pickWatermark'.tr
                    : 'imageWatermark.action.repickWatermark'.tr,
              ),
            ),
          ],
        ),
        if (watermark != null) ...[
          const SizedBox(height: 4),
          Text(
            watermark.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 10),
        EditorOptionWrap<ImageWatermarkPosition>(
          values: ImageWatermarkPosition.values,
          selected: controller.position.value,
          labelFor: (value) => value.labelKey.tr,
          enabled: !controller.isBusy.value,
          onSelected: controller.setPosition,
        ),
        const SizedBox(height: 8),
        Text(
          'imageWatermark.config.opacity'.trParams({
            'opacity': controller.opacity.value.toString(),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: controller.opacity.value.toDouble(),
          min: 10,
          max: 100,
          divisions: 18,
          label: '${controller.opacity.value}%',
          onChanged: controller.isBusy.value ? null : controller.updateOpacity,
        ),
        Text(
          'imageWatermark.config.scale'.trParams({
            'scale': controller.scalePercent.value.toString(),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: controller.scalePercent.value.toDouble(),
          min: 5,
          max: 100,
          divisions: 19,
          label: '${controller.scalePercent.value}%',
          onChanged: controller.isBusy.value ? null : controller.updateScale,
        ),
        Text(
          'imageWatermark.config.rotation'.trParams({
            'rotation': controller.rotationDegrees.value.toString(),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: controller.rotationDegrees.value.toDouble(),
          min: -180,
          max: 180,
          divisions: 72,
          label: '${controller.rotationDegrees.value}°',
          onChanged: controller.isBusy.value ? null : controller.updateRotation,
        ),
        if (controller.tasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 6),
          Text(
            'imageWatermark.progress.processed'.trParams({
              'processed': controller.processedCount.value.toString(),
              'total': controller.selectedImages.length.toString(),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
