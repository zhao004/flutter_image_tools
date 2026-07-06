import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'convert_controller.dart';

/// 图片格式转换编辑页，选择图片后按统一五段式布局展示格式与质量参数。
///
/// 设计意图：格式转换与压缩一样属于图片导出属性编辑，画布展示当前源图，
/// 标签栏固定为格式工具，属性面板负责格式和质量，底部工具栏负责批量选择
/// 与导出。异常策略：页面只触发控制器方法，格式校验、批量任务、历史记录
/// 和平台异常仍由控制器统一处理，避免 UI 层改变业务流程。
class ConvertView extends GetView<ConvertController> {
  const ConvertView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'convert.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.swap_horiz,
        emptyTitle: 'convert.image.title'.tr,
        emptyMessage: 'convert.image.empty'.tr,
        pickLabel: 'convert.action.pickSingle'.tr,
        repickLabel: 'convert.action.repickSingle'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.swap_horiz,
        onPickImage: controller.pickImage,
        onExport: controller.convert,
        imageMeta: image == null
            ? null
            : '${_selectedImageSummary()} · ${controller.format.value.label}',
        previewBuilder: (context, previewImage) =>
            EditorImagePreview(image: previewImage),
        showEditingControlsWhenEmpty: true,
        tabBar: EditorSingleToolTab(
          icon: Icons.tune_outlined,
          label: 'convert.format.title'.tr,
        ),
        toolbar: _ConvertPropertyPanel(controller: controller),
        bottomToolbar: _ConvertActionToolbar(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'convert.result.title'.tr,
                detail:
                    '${result.format.toUpperCase()} · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }

  String _selectedImageSummary() {
    final images = controller.selectedImages;
    if (images.length <= 1) {
      final image = controller.selectedImage.value;
      if (image == null) {
        return 'common.unknownSize'.tr;
      }
      return '${controller.formatBytes(image.sizeBytes)} · ${controller.formatDimensions(image)}';
    }
    final totalSize = images.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    return '${'convert.image.selectedCount'.trParams({'count': images.length.toString()})} · ${controller.formatBytes(totalSize)}';
  }
}

class _ConvertPropertyPanel extends StatelessWidget {
  const _ConvertPropertyPanel({required this.controller});

  final ConvertController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorOptionWrap<ConvertFormat>(
            values: ConvertFormat.values,
            selected: controller.format.value,
            labelFor: (value) => value.label,
            enabled: !controller.isBusy.value,
            onSelected: controller.setFormat,
          ),
          const SizedBox(height: 10),
          Text(
            'convert.quality.current'.trParams({
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
            onChanged: controller.isBusy.value ? null : controller.updateQuality,
          ),
          Text(
            controller.qualityHint(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _SelectedImagesSummary(controller: controller),
          _ConvertProgress(controller: controller),
        ],
      ),
    );
  }
}

class _SelectedImagesSummary extends StatelessWidget {
  const _SelectedImagesSummary({required this.controller});

  final ConvertController controller;

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
            'convert.image.totalSize'.trParams({
              'size': controller.formatBytes(
                images.fold<int>(0, (sum, item) => sum + item.sizeBytes),
              ),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...images.take(3).map(
                (item) => Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          if (images.length > 3)
            Text(
              'convert.image.moreCount'.trParams({
                'count': (images.length - 3).toString(),
              }),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class _ConvertProgress extends StatelessWidget {
  const _ConvertProgress({required this.controller});

  final ConvertController controller;

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
            'convert.progress.processed'.trParams({
              'processed': processed.toString(),
              'total': total.toString(),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...controller.tasks.take(3).map(
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

  String _taskStatus(ConvertTask task) {
    if (!task.isCompleted) {
      return 'convert.task.waiting'.tr;
    }
    return task.isSuccess ? 'convert.task.success'.tr : 'convert.task.failed'.tr;
  }
}

class _ConvertActionToolbar extends StatelessWidget {
  const _ConvertActionToolbar({required this.controller});

  final ConvertController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasImage = controller.selectedImage.value != null;
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: controller.isBusy.value ? null : controller.pickImages,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text('convert.action.pickBatch'.tr),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: hasImage && !controller.isBusy.value
                  ? controller.convert
                  : null,
              icon: controller.isBusy.value
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz),
              label: Text(
                controller.isBusy.value
                    ? 'common.processing'.tr
                    : 'common.saveToGallery'.tr,
              ),
            ),
          ),
        ],
      );
    });
  }
}
