import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'watermark_controller.dart';

/// 文字水印页，支持文本、位置、颜色、字号和透明度配置。
///
/// 构建设计：单图和批量共用同一组文字水印参数；批量任务顺序执行并展示进度，
/// 避免多张大图同时绘制导致内存峰值过高。
class WatermarkView extends GetView<WatermarkController> {
  const WatermarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文字水印')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _WatermarkCard(controller: controller),
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
                    : const Icon(Icons.branding_watermark_outlined),
                label: Text(controller.isBusy.value ? '处理中' : '添加水印'),
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

  final WatermarkController controller;

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
              Text('选择图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (images.isEmpty)
                const Text('请选择 JPG、PNG、WebP 或 BMP 图片添加本地文字水印。')
              else if (images.length == 1 && image != null) ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
                Text(controller.formatDimensions(image)),
              ] else ...[
                Text('已选择 ${images.length} 张图片'),
                const SizedBox(height: 4),
                Text(
                  '总大小：${controller.formatBytes(images.fold<int>(0, (sum, item) => sum + item.sizeBytes))}',
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
                    label: Text(image == null ? '选择单张' : '重新选择单张'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('批量选择'),
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
                if (images.length > 5) Text('还有 ${images.length - 5} 张图片'),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _WatermarkCard extends StatelessWidget {
  const _WatermarkCard({required this.controller});

  final WatermarkController controller;

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
              TextField(
                controller: controller.textController,
                enabled: !controller.isBusy.value,
                maxLength: 80,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '水印文字',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WatermarkPosition.values
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
              Text('颜色'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WatermarkColor.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.color.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setColor(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text('字号：${controller.fontSize.value}px'),
              Slider(
                value: controller.fontSize.value.toDouble(),
                min: 12,
                max: 160,
                divisions: 74,
                label: '${controller.fontSize.value}px',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateFontSize,
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final WatermarkController controller;

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

  final WatermarkController controller;

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
              Text('水印文字：${result.text}'),
              Text('水印位置：${result.position}'),
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
