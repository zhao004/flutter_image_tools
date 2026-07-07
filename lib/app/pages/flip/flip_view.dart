import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'flip_controller.dart';

/// 图片翻转编辑页，选择图片后在画布中实时预览翻转方向。
///
/// 设计意图：单图编辑优先展示即时效果，底部只保留方向选择；
/// 用户点击右上角保存时继续复用原有处理和历史记录逻辑。
class FlipView extends GetView<FlipController> {
  const FlipView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'flip.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.flip_outlined,
        emptyTitle: 'flip.image.title'.tr,
        emptyMessage: 'flip.image.empty'.tr,
        pickLabel: 'flip.action.pickSingle'.tr,
        repickLabel: 'flip.action.repickSingle'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.flip,
        imageMeta: image == null
            ? null
            : '${controller.formatBytes(image.sizeBytes)} · ${controller.selectedImages.length > 1 ? 'flip.image.selectedCount'.trParams({'count': controller.selectedImages.length.toString()}) : controller.labelForDirectionValue(controller.direction.value.value)}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          transform: Matrix4.diagonal3Values(
            controller.direction.value == FlipDirection.horizontal ? -1 : 1,
            controller.direction.value == FlipDirection.vertical ? -1 : 1,
            1,
          ),
        ),
        tabBar: EditorSingleToolTab(
          icon: Icons.flip_outlined,
          label: 'flip.direction.title'.tr,
        ),
        toolbar: _FlipPropertyPanel(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'flip.result.title'.tr,
                detail:
                    '${controller.labelForDirectionValue(result.direction)} · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }
}

class _FlipPropertyPanel extends StatelessWidget {
  const _FlipPropertyPanel({required this.controller});

  final FlipController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'flip.direction.title'.tr,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        EditorOptionWrap<FlipDirection>(
          values: FlipDirection.values,
          selected: controller.direction.value,
          labelFor: (value) => value.label,
          enabled: !controller.isBusy.value,
          onSelected: controller.setDirection,
        ),
        if (controller.tasks.isNotEmpty) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 6),
          Text(
            'flip.progress.processed'.trParams({
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
