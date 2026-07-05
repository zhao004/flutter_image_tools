import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'merge_controller.dart';

/// 图片拼接页，支持横向、纵向和网格布局的本地图片拼接。
///
/// 构建设计：先提供确定性布局参数，图片顺序沿用系统选择器返回顺序；
/// 后续可在此基础上增加拖拽排序、背景色和边框设置。
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
                ...images
                    .take(8)
                    .map(
                      (image) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          image.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                if (images.length > 8) Text('还有 ${images.length - 8} 张图片'),
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
              const Text('图片会在对应行、列或网格单元内居中对齐。'),
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
              Text('背景颜色：${result.backgroundColor}'),
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
