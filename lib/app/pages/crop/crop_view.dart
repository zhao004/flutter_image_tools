import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../widgets/image_editor_scaffold.dart';
import 'crop_controller.dart';

/// 图片裁剪编辑页：选择图片后在画布上实时显示可拖动裁剪比例框。
///
/// 设计意图：裁剪框位置使用归一化比例同步到控制器，预览层只负责手势和
/// 即时反馈；导出前仍由控制器和服务层校验比例与边界，避免无效区域。
class CropView extends GetView<CropController> {
  const CropView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'crop.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.crop_outlined,
        emptyTitle: 'crop.image.title'.tr,
        emptyMessage: 'crop.image.empty'.tr,
        pickLabel: 'crop.action.pickSingle'.tr,
        repickLabel: 'crop.action.repickSingle'.tr,
        exportLabel: 'crop.action.crop'.tr,
        exportIcon: Icons.save_alt_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.crop,
        previewBorderRadius: 12,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${controller.currentRatioText()}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          child: _CropOverlay(
            image: previewImage,
            controller: controller,
            aspectRatio: _previewAspectRatio(),
          ),
        ),
        toolbar: _CropToolbar(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'crop.result.title'.tr,
                detail:
                    '${result.width} × ${result.height} px · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }

  double _previewAspectRatio() {
    final preset = controller.preset.value;
    if (preset != CropPreset.custom) {
      return preset.aspectRatio;
    }
    final width = double.tryParse(controller.customWidthController.text.trim());
    final height = double.tryParse(
      controller.customHeightController.text.trim(),
    );
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 1;
    }
    return (width / height).clamp(0.1, 10);
  }
}

class _CropOverlay extends StatelessWidget {
  const _CropOverlay({
    required this.image,
    required this.controller,
    required this.aspectRatio,
  });

  final LocalImageFile image;
  final CropController controller;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Obx(() {
          final stageWidth = constraints.maxWidth;
          final stageHeight = constraints.maxHeight;
          final frameRatios = controller.frameRatiosForImage(
            image,
            aspectRatio,
          );
          final frameWidth = stageWidth * frameRatios.width;
          final frameHeight = stageHeight * frameRatios.height;
          final frameLeft = stageWidth * frameRatios.left;
          final frameTop = stageHeight * frameRatios.top;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Positioned(
                left: frameLeft,
                top: frameTop,
                width: frameWidth,
                height: frameHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: controller.isBusy.value
                      ? null
                      : (details) {
                          if (stageWidth <= 0 || stageHeight <= 0) {
                            return;
                          }
                          controller.updateCropFrame(
                            centerXRatio:
                                controller.cropCenterXRatio.value +
                                details.delta.dx / stageWidth,
                            centerYRatio:
                                controller.cropCenterYRatio.value +
                                details.delta.dy / stageHeight,
                            frameWidthRatio: frameRatios.width,
                            frameHeightRatio: frameRatios.height,
                          );
                        },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class _CropToolbar extends StatelessWidget {
  const _CropToolbar({required this.controller});

  final CropController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'crop.ratio.title'.tr,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'crop.ratio.current'.trParams({
                  'ratio': controller.currentRatioText(),
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        EditorOptionWrap<CropPreset>(
          values: CropPreset.values,
          selected: controller.preset.value,
          labelFor: (value) => '${value.labelKey.tr} ${value.ratioText.tr}',
          enabled: !controller.isBusy.value,
          onSelected: controller.setPreset,
        ),
        if (controller.preset.value == CropPreset.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.customWidthController,
                  enabled: !controller.isBusy.value,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => controller.preset.refresh(),
                  decoration: InputDecoration(
                    labelText: 'crop.ratio.width'.tr,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller.customHeightController,
                  enabled: !controller.isBusy.value,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => controller.preset.refresh(),
                  decoration: InputDecoration(
                    labelText: 'crop.ratio.height'.tr,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (controller.tasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 6),
          Text(
            'crop.progress.processed'.trParams({
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
