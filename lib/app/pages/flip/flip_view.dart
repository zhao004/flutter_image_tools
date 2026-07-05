import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'flip_controller.dart';

/// 图片翻转页，支持水平和垂直方向本地翻转。
///
/// 构建设计：翻转功能保持单图闭环，复用本地图片通道和历史记录；后续批量
/// 翻转可以直接复用压缩功能的任务队列模型。
class FlipView extends GetView<FlipController> {
  const FlipView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片翻转')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _DirectionCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.flip,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flip),
                label: Text(controller.isBusy.value ? '翻转中' : '开始翻转'),
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

  final FlipController controller;

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
                const Text('请选择一张 JPG、PNG、WebP 或 BMP 图片进行本地翻转。')
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    controller.isBusy.value ? null : controller.pickImage,
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

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({required this.controller});

  final FlipController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('翻转方向', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<FlipDirection>(
                segments: FlipDirection.values
                    .map(
                      (item) => ButtonSegment(
                        value: item,
                        label: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                selected: {controller.direction.value},
                onSelectionChanged: (values) =>
                    controller.setDirection(values.first),
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

  final FlipController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const SizedBox.shrink();
      }
      final direction = result.direction == FlipDirection.horizontal.value
          ? '水平翻转'
          : '垂直翻转';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('翻转结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('翻转方向：$direction'),
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
