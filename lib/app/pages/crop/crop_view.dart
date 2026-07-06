import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'crop_controller.dart';

/// 图片裁剪编辑页：选择图片后在画布上实时显示中心裁剪比例框。
///
/// 设计意图：当前原生能力是中心裁剪，因此预览层用比例遮罩明确导出区域；
/// 自定义比例仍在控制器导出前校验，UI 只负责即时反馈和参数输入。
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
        exportIcon: Icons.ios_share_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.crop,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${controller.currentRatioText()}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          child: _CropOverlay(aspectRatio: _previewAspectRatio()),
        ),
        toolbar: _CropToolbar(controller: controller),
        appBarActions: [
          IconButton(
            tooltip: 'crop.action.pickBatch'.tr,
            onPressed: controller.isBusy.value ? null : controller.pickImages,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
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
  const _CropOverlay({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageWidth = constraints.maxWidth;
        final stageHeight = constraints.maxHeight;
        var frameWidth = stageWidth;
        var frameHeight = frameWidth / aspectRatio;
        if (frameHeight > stageHeight) {
          frameHeight = stageHeight;
          frameWidth = frameHeight * aspectRatio;
        }
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ),
            Center(
              child: Container(
                width: frameWidth,
                height: frameHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        );
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
        Text(
          'crop.ratio.title'.tr,
          style: Theme.of(context).textTheme.titleSmall,
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
        const SizedBox(height: 8),
        Text(
          'crop.ratio.current'.trParams({
            'ratio': controller.currentRatioText(),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
