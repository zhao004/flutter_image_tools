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
        bottomToolbar: _FlipBottomToolPanel(controller: controller),
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

class _FlipBottomToolPanel extends StatelessWidget {
  const _FlipBottomToolPanel({required this.controller});

  final FlipController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => EditorDynamicToolPanel(
        categories: [
          ToolCategory(
            id: 'direction',
            name: 'flip.direction.title'.tr,
            icon: Icons.flip_outlined,
            subItems: FlipDirection.values
                .map(
                  (direction) => ToolSubItem(
                    id: direction.value,
                    name: direction.label,
                    icon: direction == FlipDirection.horizontal
                        ? Icons.swap_horiz
                        : Icons.swap_vert,
                  ),
                )
                .toList(growable: false),
          ),
        ],
        activeCategoryId: 'direction',
        activeSubItemId: controller.direction.value.value,
        activePanelTitle: 'flip.direction.title'.tr,
        activePanel: _FlipProgressPanel(controller: controller),
        onCategorySelected: (_) {},
        onSubItemSelected: (item) {
          final direction = FlipDirection.values.firstWhereOrNull(
            (value) => value.value == item.id,
          );
          if (direction != null) {
            controller.setDirection(direction);
          }
        },
      ),
    );
  }
}

class _FlipProgressPanel extends StatelessWidget {
  const _FlipProgressPanel({required this.controller});

  final FlipController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }
}
