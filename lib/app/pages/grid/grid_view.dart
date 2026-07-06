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
      appBar: AppBar(title: Text('grid.title'.tr)),
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
                label: Text(
                  controller.isBusy.value
                      ? 'common.processing'.tr
                      : 'grid.action.split'.tr,
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
              Text(
                'grid.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                Text('grid.image.empty'.tr)
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
                label: Text(
                  image == null
                      ? 'grid.action.pickImage'.tr
                      : 'grid.action.repickImage'.tr,
                ),
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
              Text(
                'grid.size.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
              Text(
                'grid.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'grid.result.gridSize'.trParams({'size': '${result.gridSize}'}),
              ),
              Text(
                'grid.result.pieceCount'.trParams({
                  'count': '${result.pieceCount}',
                }),
              ),
              Text(
                'grid.result.outputSize'.trParams({
                  'size': controller.formatBytes(result.outputSizeBytes),
                }),
              ),
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
                  'grid.result.morePieces'.trParams({
                    'count':
                        '${result.outputPaths.length - previewPaths.length}',
                  }),
                ),
            ],
          ),
        ),
      );
    });
  }
}
