import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'grid_controller.dart';

/// 九宫格切图页，支持将单张图片切成 2×2 到 5×5 的编号切片。
///
/// 构建设计：当前阶段采用固定网格选项，保证输出数量和命名可预期；自由
/// NxN 可在后续加入数值输入，同时复用现有通道和结果模型。
class GridView extends GetView<GridController> {
  const GridView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('九宫格切图')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _GridSizeCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.splitImage,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.grid_view_outlined),
                label: Text(controller.isBusy.value ? '处理中' : '生成切片'),
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

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final image = controller.selectedImage.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (image == null)
                const Text('请选择一张 JPG、PNG、WebP 或 BMP 图片生成网格切片。')
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
                Text(controller.formatDimensions(image)),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(image == null ? '选择图片' : '重新选择'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _GridSizeCard extends StatelessWidget {
  const _GridSizeCard({required this.controller});

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('网格大小', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [2, 3, 4, 5]
                    .map(
                      (size) => ChoiceChip(
                        label: Text('$size × $size'),
                        selected: controller.gridSize.value == size,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setGridSize(size),
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

  final GridController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const SizedBox.shrink();
      }
      final previewPaths = result.outputPaths.take(5).toList(growable: false);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('切图结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('网格大小：${result.gridSize} × ${result.gridSize}'),
              Text('切片数量：${result.pieceCount} 张'),
              Text('导出大小：${controller.formatBytes(result.outputSizeBytes)}'),
              const SizedBox(height: 8),
              Text(
                result.outputDirectory,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ...previewPaths.map(
                (path) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              if (result.outputPaths.length > previewPaths.length)
                Text(
                  '还有 ${result.outputPaths.length - previewPaths.length} 张切片',
                ),
            ],
          ),
        ),
      );
    });
  }
}
