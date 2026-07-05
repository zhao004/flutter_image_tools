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
      appBar: AppBar(title: const Text('图片拼接')),
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
                label: Text(controller.isBusy.value ? '拼接中' : '开始拼接'),
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
              Text('选择图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (images.isEmpty)
                const Text('请选择 2 到 20 张 JPG、PNG、WebP 或 BMP 图片进行本地拼接。')
              else ...[
                Text('已选择 ${images.length} 张图片'),
                const SizedBox(height: 4),
                Text(
                  '总大小：${controller.formatBytes(controller.totalSizeBytes)}',
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(images.isEmpty ? '批量选择' : '重新选择'),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('拖动右侧图标可调整拼接顺序。'),
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
              Text('拼接布局', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<MergeMode>(
                segments: MergeMode.values
                    .map(
                      (item) =>
                          ButtonSegment(value: item, label: Text(item.label)),
                    )
                    .toList(growable: false),
                selected: {controller.mode.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setMode(values.first),
              ),
              if (controller.mode.value == MergeMode.grid) ...[
                const SizedBox(height: 16),
                Text('网格列数：${controller.columns.value}'),
                Slider(
                  value: controller.columns.value.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${controller.columns.value} 列',
                  onChanged: controller.isBusy.value
                      ? null
                      : controller.updateColumns,
                ),
              ],
              if (controller.mode.value == MergeMode.long) ...[
                const SizedBox(height: 12),
                const Text('长图模式会按选择顺序纵向拼接，并默认统一图片宽度。'),
              ],
              const SizedBox(height: 16),
              Text('图片间距：${controller.spacing.value}px'),
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
              const Text('背景颜色'),
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
                        label: Text(item.label),
                        selected: controller.backgroundColor.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setBackgroundColor(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              const Text('自动缩放'),
              const SizedBox(height: 8),
              SegmentedButton<MergeScaleMode>(
                segments: MergeScaleMode.values
                    .map(
                      (item) =>
                          ButtonSegment(value: item, label: Text(item.label)),
                    )
                    .toList(growable: false),
                selected: {controller.scaleMode.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setScaleMode(values.first),
              ),
              const SizedBox(height: 12),
              const Text('图片会按缩放策略处理后，在对应行、列或网格单元内居中对齐。'),
              const SizedBox(height: 16),
              Text('圆角半径：${controller.cornerRadius.value}px'),
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
              Text('边框宽度：${controller.borderWidth.value}px'),
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
              const Text('边框颜色'),
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
                        label: Text(item.label),
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
              Text('拼接结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('输入数量：${result.sources.length} 张'),
              Text('布局模式：${result.mode}'),
              Text('缩放模式：${result.scaleMode}'),
              Text('背景颜色：${result.backgroundColor}'),
              Text('圆角半径：${result.cornerRadius}px'),
              Text('边框：${result.borderWidth}px / ${result.borderColor}'),
              Text('输出尺寸：${result.width} × ${result.height} px'),
              Text('导出大小：${controller.formatBytes(result.outputSizeBytes)}'),
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
