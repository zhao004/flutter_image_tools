import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'rotate_controller.dart';

/// 图片旋转页，支持 90°、180° 和自定义角度本地旋转。
///
/// 构建设计：单图和批量共用同一角度参数；批量任务顺序执行并展示进度，
/// 避免多张大图并发处理造成内存抖动。
class RotateView extends GetView<RotateController> {
  const RotateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('rotate.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _AngleCard(controller: controller),
            const SizedBox(height: 16),
            _ProgressCard(controller: controller),
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
                label: Text(
                  controller.isBusy.value
                      ? 'common.processing'.tr
                      : 'rotate.action.rotate'.tr,
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

  final RotateController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final images = controller.selectedImages;
          final image = controller.selectedImage.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'rotate.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (images.isEmpty)
                Text('rotate.image.empty'.tr)
              else if (images.length == 1 && image != null) ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
              ] else ...[
                Text(
                  'rotate.image.selectedCount'.trParams({
                    'count': images.length.toString(),
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  'rotate.image.totalSize'.trParams({
                    'size': controller.formatBytes(
                      images.fold<int>(0, (sum, item) => sum + item.sizeBytes),
                    ),
                  }),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      image == null
                          ? 'rotate.action.pickSingle'.tr
                          : 'rotate.action.repickSingle'.tr,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text('rotate.action.pickBatch'.tr),
                  ),
                ],
              ),
              if (images.length > 1) ...[
                const SizedBox(height: 12),
                ...images
                    .take(5)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                if (images.length > 5)
                  Text(
                    'rotate.image.moreCount'.trParams({
                      'count': (images.length - 5).toString(),
                    }),
                  ),
              ],
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
              Text(
                'rotate.angle.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('rotate.angle.left90'.tr),
                    selected: controller.degrees.value == -90,
                    onSelected: (_) => controller.setDegrees(-90),
                  ),
                  ChoiceChip(
                    label: Text('rotate.angle.right90'.tr),
                    selected: controller.degrees.value == 90,
                    onSelected: (_) => controller.setDegrees(90),
                  ),
                  ChoiceChip(
                    label: Text('rotate.angle.oneEighty'.tr),
                    selected: controller.degrees.value == 180,
                    onSelected: (_) => controller.setDegrees(180),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'rotate.angle.custom'.trParams({
                  'degrees': controller.degrees.value.toString(),
                }),
              ),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final RotateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.tasks.isEmpty) {
        return const SizedBox.shrink();
      }
      final total = controller.selectedImages.length;
      final processed = controller.processedCount.value;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'rotate.progress.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: controller.progress),
              const SizedBox(height: 8),
              Text(
                'rotate.progress.processed'.trParams({
                  'processed': processed.toString(),
                  'total': total.toString(),
                }),
              ),
              const SizedBox(height: 12),
              ...controller.tasks.map((task) {
                final status = task.isCompleted
                    ? task.isSuccess
                          ? 'rotate.task.success'.tr
                          : 'rotate.task.failed'.tr
                    : 'rotate.task.waiting'.tr;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    task.isCompleted
                        ? task.isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline
                        : Icons.hourglass_empty,
                  ),
                  title: Text(
                    task.source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(task.errorMessage ?? status),
                );
              }),
            ],
          ),
        ),
      );
    });
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
              Text(
                'rotate.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'rotate.result.degrees'.trParams({
                  'degrees': result.degrees.toString(),
                }),
              ),
              Text(
                'rotate.result.outputSize'.trParams({
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
