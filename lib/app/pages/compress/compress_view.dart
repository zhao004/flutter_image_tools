import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'compress_controller.dart';

/// 图片压缩页，提供单图选择、质量调节、执行压缩和结果展示。
///
/// 构建设计：页面保持单任务闭环，批量队列后续独立抽取；按钮在处理中禁用，
/// 避免重复触发原生压缩造成文件覆盖或状态错乱。
class CompressView extends GetView<CompressController> {
  const CompressView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片压缩')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePickerCard(controller: controller),
            const SizedBox(height: 16),
            _QualityCard(controller: controller),
            const SizedBox(height: 16),
            _ProgressCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.compress,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compress),
                label: Text(controller.isBusy.value ? '压缩中' : '开始压缩'),
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

  final CompressController controller;

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
                const Text('请选择 JPG、PNG 或 WebP 图片进行本地压缩。')
              else if (images.length == 1 && image != null) ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
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
                    onPressed:
                        controller.isBusy.value ? null : controller.pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(image == null ? '选择单张' : '重新选择单张'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        controller.isBusy.value ? null : controller.pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('批量选择'),
                  ),
                ],
              ),
              if (images.length > 1) ...[
                const SizedBox(height: 12),
                ...images.take(5).map(
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final CompressController controller;

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

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('压缩质量', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('当前质量：${controller.quality.value}%'),
              Slider(
                value: controller.quality.value.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '${controller.quality.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateQuality,
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

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const SizedBox.shrink();
      }
      final savedPercent = (result.savedRatio * 100).toStringAsFixed(1);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('压缩结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('原始大小：${controller.formatBytes(result.source.sizeBytes)}'),
              Text('导出大小：${controller.formatBytes(result.outputSizeBytes)}'),
              Text('节省空间：$savedPercent%'),
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
