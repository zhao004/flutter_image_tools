import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'rotate_controller.dart';

/// 图片旋转页，支持 90°、180° 和自定义角度本地旋转。
///
/// 构建设计：旋转作为独立单图任务，先保障结果可导出和可追踪；批量旋转
/// 后续可复用压缩页的队列模型扩展。
class RotateView extends GetView<RotateController> {
  const RotateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片旋转')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _AngleCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.rotate,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rotate_90_degrees_ccw),
                label: Text(controller.isBusy.value ? '旋转中' : '开始旋转'),
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

  final RotateController controller;

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
                const Text('请选择一张 JPG、PNG、WebP 或 BMP 图片进行本地旋转。')
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

class _AngleCard extends StatelessWidget {
  const _AngleCard({required this.controller});

  final RotateController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('旋转角度', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('左旋 90°'),
                    selected: controller.degrees.value == -90,
                    onSelected: (_) => controller.setDegrees(-90),
                  ),
                  ChoiceChip(
                    label: const Text('右旋 90°'),
                    selected: controller.degrees.value == 90,
                    onSelected: (_) => controller.setDegrees(90),
                  ),
                  ChoiceChip(
                    label: const Text('180°'),
                    selected: controller.degrees.value == 180,
                    onSelected: (_) => controller.setDegrees(180),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('自定义角度：${controller.degrees.value}°'),
              Slider(
                value: controller.degrees.value.clamp(-180, 180).toDouble(),
                min: -180,
                max: 180,
                divisions: 360,
                label: '${controller.degrees.value}°',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateCustomDegrees,
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

  final RotateController controller;

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
              Text('旋转结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('旋转角度：${result.degrees}°'),
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
