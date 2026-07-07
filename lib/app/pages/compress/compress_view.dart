import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'compress_controller.dart';

/// 图片压缩编辑页，选择图片后按统一五段式布局展示压缩参数和任务状态。
///
/// 设计意图：压缩虽然不改变画面像素预览，但仍属于图片属性编辑流程；
/// 使用统一骨架后，选图、画布、参数、进度和顶部导出入口与其他编辑页一致。
/// 异常策略：页面只读取控制器状态并触发控制器方法，校验、批量任务、
/// 历史记录和平台异常仍由控制器处理，避免 UI 层复制业务逻辑。
class CompressView extends GetView<CompressController> {
  const CompressView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'compress.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.compress,
        emptyTitle: 'compress.image.title'.tr,
        emptyMessage: 'compress.image.empty'.tr,
        pickLabel: 'compress.action.pickSingle'.tr,
        repickLabel: 'compress.action.repickSingle'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.compress,
        onPickImage: controller.pickImage,
        onExport: controller.compress,
        imageMeta: image == null
            ? null
            : '${_selectedImageSummary()} · ${'compress.quality.current'.trParams({'quality': controller.quality.value.toString()})}',
        previewBuilder: (context, previewImage) =>
            EditorImagePreview(image: previewImage),
        showEditingControlsWhenEmpty: true,
        bottomToolbar: _CompressBottomToolPanel(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'compress.result.title'.tr,
                detail:
                    '${controller.formatBytes(result.outputSizeBytes)} · ${'compress.result.saved'.trParams({'percent': (result.savedRatio * 100).toStringAsFixed(1)})}',
                tooltip: result.outputPath,
              ),
      );
    });
  }

  String _selectedImageSummary() {
    final images = controller.selectedImages;
    if (images.length <= 1) {
      final image = controller.selectedImage.value;
      return image == null
          ? 'common.unknownSize'.tr
          : controller.formatBytes(image.sizeBytes);
    }
    final totalSize = images.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    return '${'compress.image.selectedCount'.trParams({'count': images.length.toString()})} · ${controller.formatBytes(totalSize)}';
  }
}

class _CompressBottomToolPanel extends StatelessWidget {
  const _CompressBottomToolPanel({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return EditorDynamicToolPanel(
      categories: [
        ToolCategory(
          id: 'quality',
          name: 'compress.quality.title'.tr,
          icon: Icons.tune_outlined,
        ),
      ],
      activeCategoryId: 'quality',
      activePanelTitle: 'compress.quality.title'.tr,
      activePanel: _CompressPropertyPanel(controller: controller),
      onCategorySelected: (_) {},
    );
  }
}

class _CompressPropertyPanel extends StatelessWidget {
  const _CompressPropertyPanel({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'compress.quality.current'.trParams({
              'quality': controller.quality.value.toString(),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            value: controller.quality.value.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            label: '${controller.quality.value}%',
            onChanged: controller.isBusy.value
                ? null
                : controller.updateQuality,
          ),
          _SelectedImagesSummary(controller: controller),
          _CompressionProgress(controller: controller),
        ],
      ),
    );
  }
}

class _SelectedImagesSummary extends StatelessWidget {
  const _SelectedImagesSummary({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    final images = controller.selectedImages;
    if (images.length <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'compress.image.totalSize'.trParams({
              'size': controller.formatBytes(
                images.fold<int>(0, (sum, item) => sum + item.sizeBytes),
              ),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...images
              .take(3)
              .map(
                (item) => Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          if (images.length > 3)
            Text(
              'compress.image.moreCount'.trParams({
                'count': (images.length - 3).toString(),
              }),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class _CompressionProgress extends StatelessWidget {
  const _CompressionProgress({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    final total = controller.selectedImages.length;
    final processed = controller.processedCount.value;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 6),
          Text(
            'compress.progress.processed'.trParams({
              'processed': processed.toString(),
              'total': total.toString(),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...controller.tasks
              .take(3)
              .map(
                (task) => Text(
                  '${task.source.name} · ${_taskStatus(task)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
        ],
      ),
    );
  }

  String _taskStatus(CompressionTask task) {
    if (!task.isCompleted) {
      return 'compress.task.waiting'.tr;
    }
    return task.isSuccess
        ? 'compress.task.success'.tr
        : 'compress.task.failed'.tr;
  }
}
