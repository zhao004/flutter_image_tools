import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'merge_controller.dart';

/// 图片拼接页，支持横向、纵向和网格布局的本地图片拼接。
///
/// 构建设计：图片顺序既可沿用系统选择器结果，也可在本页拖拽调整；
/// 拼接前所有布局参数都会传入本地通道，避免 UI 状态和导出结果不一致。
class MergeView extends GetView<MergeController> {
  const MergeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merge.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePickerCard(controller: controller),
            const SizedBox(height: 16),
            _LayoutCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.merge,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.view_column_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'common.processing'.tr
                      : 'merge.action.merge'.tr,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ResultCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final images = controller.selectedImages;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'merge.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (images.isEmpty)
                Text('merge.image.empty'.tr)
              else ...[
                Text(
                  'merge.image.selectedCount'.trParams({
                    'count': images.length.toString(),
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  'merge.image.totalSize'.trParams({
                    'size': controller.formatBytes(controller.totalSizeBytes),
                  }),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  images.isEmpty
                      ? 'merge.action.pickBatch'.tr
                      : 'merge.action.repickBatch'.tr,
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('merge.image.reorderHint'.tr),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  onReorder: controller.reorderSelectedImages,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final image = images[index];
                    return ListTile(
                      key: ValueKey('${image.path}#$index'),
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(
                        image.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(controller.formatBytes(image.sizeBytes)),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        enabled: !controller.isBusy.value,
                        child: const Icon(Icons.drag_handle),
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'merge.layout.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<MergeMode>(
                segments: MergeMode.values
                    .map(
                      (item) => ButtonSegment(
                        value: item,
                        label: Text(item.labelKey.tr),
                      ),
                    )
                    .toList(growable: false),
                selected: {controller.mode.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setMode(values.first),
              ),
              if (controller.mode.value == MergeMode.grid) ...[
                const SizedBox(height: 16),
                Text(
                  'merge.layout.columns'.trParams({
                    'count': controller.columns.value.toString(),
                  }),
                ),
                Slider(
                  value: controller.columns.value.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: 'merge.layout.columnsLabel'.trParams({
                    'count': controller.columns.value.toString(),
                  }),
                  onChanged: controller.isBusy.value
                      ? null
                      : controller.updateColumns,
                ),
              ],
              if (controller.mode.value == MergeMode.long) ...[
                const SizedBox(height: 12),
                Text('merge.layout.longHint'.tr),
              ],
              const SizedBox(height: 16),
              Text(
                'merge.layout.spacing'.trParams({
                  'value': controller.spacing.value.toString(),
                }),
              ),
              Slider(
                value: controller.spacing.value.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${controller.spacing.value}px',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateSpacing,
              ),
              const SizedBox(height: 16),
              Text('merge.layout.backgroundColor'.tr),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MergeBackgroundColor.values
                    .map(
                      (item) => ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: _parseColor(item.value),
                          radius: 8,
                        ),
                        label: Text(item.labelKey.tr),
                        selected: controller.backgroundColor.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setBackgroundColor(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Text('merge.layout.scaleMode'.tr),
              const SizedBox(height: 8),
              SegmentedButton<MergeScaleMode>(
                segments: MergeScaleMode.values
                    .map(
                      (item) => ButtonSegment(
                        value: item,
                        label: Text(item.labelKey.tr),
                      ),
                    )
                    .toList(growable: false),
                selected: {controller.scaleMode.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setScaleMode(values.first),
              ),
              const SizedBox(height: 12),
              Text('merge.layout.scaleHint'.tr),
              const SizedBox(height: 16),
              Text(
                'merge.layout.cornerRadius'.trParams({
                  'value': controller.cornerRadius.value.toString(),
                }),
              ),
              Slider(
                value: controller.cornerRadius.value.toDouble(),
                min: 0,
                max: 200,
                divisions: 20,
                label: '${controller.cornerRadius.value}px',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateCornerRadius,
              ),
              const SizedBox(height: 16),
              Text(
                'merge.layout.borderWidth'.trParams({
                  'value': controller.borderWidth.value.toString(),
                }),
              ),
              Slider(
                value: controller.borderWidth.value.toDouble(),
                min: 0,
                max: 50,
                divisions: 10,
                label: '${controller.borderWidth.value}px',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateBorderWidth,
              ),
              const SizedBox(height: 8),
              Text('merge.layout.borderColor'.tr),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MergeBorderColor.values
                    .map(
                      (item) => ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: _parseColor(item.value),
                          radius: 8,
                        ),
                        label: Text(item.labelKey.tr),
                        selected: controller.borderColor.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setBorderColor(item),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const SizedBox.shrink();
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'merge.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'merge.result.inputCount'.trParams({
                  'count': result.sources.length.toString(),
                }),
              ),
              Text('merge.result.mode'.trParams({'mode': result.mode})),
              Text(
                'merge.result.scaleMode'.trParams({'mode': result.scaleMode}),
              ),
              Text(
                'merge.result.backgroundColor'.trParams({
                  'color': result.backgroundColor,
                }),
              ),
              Text(
                'merge.result.cornerRadius'.trParams({
                  'value': result.cornerRadius.toString(),
                }),
              ),
              Text(
                'merge.result.border'.trParams({
                  'width': result.borderWidth.toString(),
                  'color': result.borderColor,
                }),
              ),
              Text(
                'merge.result.dimensions'.trParams({
                  'width': result.width.toString(),
                  'height': result.height.toString(),
                }),
              ),
              Text(
                'merge.result.outputSize'.trParams({
                  'size': controller.formatBytes(result.outputSizeBytes),
                }),
              ),
              const SizedBox(height: 8),
              Text(
                result.outputPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    });
  }
}

Color _parseColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}
