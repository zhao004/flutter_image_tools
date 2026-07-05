import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/local_image_file.dart';
import 'image_watermark_controller.dart';

/// 图片水印页，支持 PNG/Logo/二维码图片作为水印叠加到底图上。
///
/// 构建设计：单图和批量共用同一张水印图和参数；批量任务顺序执行并展示进度，
/// 避免多张大图同时合成导致内存峰值过高。
class ImageWatermarkView extends GetView<ImageWatermarkController> {
  const ImageWatermarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片水印')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(
              title: '选择底图',
              emptyText: '请选择需要添加图片水印的底图。',
              buttonText: '选择底图',
              selectedImage: controller.selectedImage,
              selectedImages: controller.selectedImages,
              isBusy: controller.isBusy,
              onPick: controller.pickSourceImage,
              onPickMultiple: controller.pickSourceImages,
              controller: controller,
            ),
            const SizedBox(height: 16),
            _ImageCard(
              title: '选择水印图片',
              emptyText: '请选择 PNG、Logo 或二维码图片作为水印。',
              buttonText: '选择水印',
              selectedImage: controller.selectedWatermark,
              selectedImages: null,
              isBusy: controller.isBusy,
              onPick: controller.pickWatermarkImage,
              onPickMultiple: null,
              controller: controller,
            ),
            const SizedBox(height: 16),
            _WatermarkOptionsCard(controller: controller),
            const SizedBox(height: 16),
            _ProgressCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.addWatermark,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.layers_outlined),
                label: Text(controller.isBusy.value ? '处理中' : '添加图片水印'),
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
  const _ImageCard({
    required this.title,
    required this.emptyText,
    required this.buttonText,
    required this.selectedImage,
    required this.selectedImages,
    required this.isBusy,
    required this.onPick,
    required this.onPickMultiple,
    required this.controller,
  });

  final String title;
  final String emptyText;
  final String buttonText;
  final Rxn selectedImage;
  final RxList<LocalImageFile>? selectedImages;
  final RxBool isBusy;
  final VoidCallback onPick;
  final VoidCallback? onPickMultiple;
  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final image = selectedImage.value;
          final images = selectedImages;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (image == null && (images == null || images.isEmpty))
                Text(emptyText)
              else if (images != null && images.length > 1) ...[
                Text('已选择 ${images.length} 张底图'),
                const SizedBox(height: 4),
                Text(
                  '总大小：${controller.formatBytes(images.fold<int>(0, (sum, item) => sum + item.sizeBytes))}',
                ),
              ] else if (image != null) ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
                Text(controller.formatDimensions(image)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: isBusy.value ? null : onPick,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(image == null ? buttonText : '重新选择'),
                  ),
                  if (onPickMultiple != null)
                    FilledButton.tonalIcon(
                      onPressed: isBusy.value ? null : onPickMultiple,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('批量选择'),
                    ),
                ],
              ),
              if (images != null && images.length > 1) ...[
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
                if (images.length > 5) Text('还有 ${images.length - 5} 张底图'),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _WatermarkOptionsCard extends StatelessWidget {
  const _WatermarkOptionsCard({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('水印配置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ImageWatermarkPosition.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.position.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setPosition(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text('透明度：${controller.opacity.value}%'),
              Slider(
                value: controller.opacity.value.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                label: '${controller.opacity.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateOpacity,
              ),
              Text('缩放：${controller.scalePercent.value}%'),
              Slider(
                value: controller.scalePercent.value.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                label: '${controller.scalePercent.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateScale,
              ),
              Text('旋转：${controller.rotationDegrees.value}°'),
              Slider(
                value: controller.rotationDegrees.value.toDouble(),
                min: -180,
                max: 180,
                divisions: 72,
                label: '${controller.rotationDegrees.value}°',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateRotation,
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

  final ImageWatermarkController controller;

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
              Text('批量进度', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: controller.progress),
              const SizedBox(height: 8),
              Text('已处理 $processed / $total 张'),
              const SizedBox(height: 12),
              ...controller.tasks.map((task) {
                final status = task.isCompleted
                    ? task.isSuccess
                          ? '成功'
                          : '失败'
                    : '等待';
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

  final ImageWatermarkController controller;

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
              Text('水印结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('水印图片：${result.watermark.name}'),
              Text('位置：${result.position}'),
              Text('透明度：${result.opacity}%'),
              Text('缩放：${result.scalePercent}%'),
              Text('旋转：${result.rotationDegrees}°'),
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
