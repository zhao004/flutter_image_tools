import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'resize_controller.dart';

/// 图片尺寸调整页，支持按目标宽高和百分比缩放本地图片。
///
/// 构建设计：单图可使用精确目标宽高；批量保持比例时按百分比逐图缩放，
/// 避免不同宽高比图片被拉伸到同一尺寸。
class ResizeView extends GetView<ResizeController> {
  const ResizeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('尺寸调整')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _SizeCard(controller: controller),
            const SizedBox(height: 16),
            _ProgressCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.resize,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.aspect_ratio),
                label: Text(controller.isBusy.value ? '调整中' : '开始调整'),
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

  final ResizeController controller;

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
                const Text('请选择 JPG、PNG、WebP 或 BMP 图片进行本地尺寸调整。')
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

class _SizeCard extends StatelessWidget {
  const _SizeCard({required this.controller});

  final ResizeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('目标尺寸', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保持原比例'),
                value: controller.keepAspectRatio.value,
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateKeepAspectRatio,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.widthController,
                      enabled: !controller.isBusy.value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '宽度',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: controller.updateWidth,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller.heightController,
                      enabled: !controller.isBusy.value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '高度',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: controller.updateHeight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('按比例缩放：${controller.percent.value.round()}%'),
              Slider(
                value: controller.percent.value.clamp(10, 300),
                min: 10,
                max: 300,
                divisions: 58,
                label: '${controller.percent.value.round()}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updatePercent,
              ),
              const Text('支持 10% 到 300%，最大单边 10000 像素。'),
              if (controller.selectedImages.length > 1 &&
                  controller.keepAspectRatio.value) ...[
                const SizedBox(height: 8),
                const Text('批量保持原比例时，会按当前百分比分别缩放每张图片。'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final ResizeController controller;

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

  final ResizeController controller;

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
              Text('调整结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('目标尺寸：${result.width} × ${result.height} px'),
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
