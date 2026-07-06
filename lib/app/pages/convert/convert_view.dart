import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'convert_controller.dart';

/// 图片格式转换页，支持 JPG、PNG、WebP 和 BMP 本地导出。
///
/// 构建设计：单图和批量共用目标格式与质量参数；批量任务顺序执行并展示
/// 进度，避免多张大图同时编码造成内存峰值过高。
class ConvertView extends GetView<ConvertController> {
  const ConvertView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('convert.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _FormatCard(controller: controller),
            const SizedBox(height: 16),
            _ProgressCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.convert,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz),
                label: Text(
                  controller.isBusy.value
                      ? 'common.processing'.tr
                      : 'common.saveToGallery'.tr,
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

  final ConvertController controller;

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
                'convert.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (images.isEmpty)
                Text('convert.image.empty'.tr)
              else if (images.length == 1 && image != null) ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
                Text(controller.formatDimensions(image)),
              ] else ...[
                Text(
                  'convert.image.selectedCount'.trParams({
                    'count': images.length.toString(),
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  'convert.image.totalSize'.trParams({
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
                          ? 'convert.action.pickSingle'.tr
                          : 'convert.action.repickSingle'.tr,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text('convert.action.pickBatch'.tr),
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
                    'convert.image.moreCount'.trParams({
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

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.controller});

  final ConvertController controller;

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
                'convert.format.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ConvertFormat.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.format.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setFormat(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text(
                'convert.quality.current'.trParams({
                  'quality': controller.quality.value.toString(),
                }),
              ),
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
              Text(controller.qualityHint()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final ConvertController controller;

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
                'convert.progress.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: controller.progress),
              const SizedBox(height: 8),
              Text(
                'convert.progress.processed'.trParams({
                  'processed': processed.toString(),
                  'total': total.toString(),
                }),
              ),
              const SizedBox(height: 12),
              ...controller.tasks.map((task) {
                final status = task.isCompleted
                    ? task.isSuccess
                          ? 'convert.task.success'.tr
                          : 'convert.task.failed'.tr
                    : 'convert.task.waiting'.tr;
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

  final ConvertController controller;

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
                'convert.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'convert.result.format'.trParams({
                  'format': result.format.toUpperCase(),
                }),
              ),
              Text('convert.result.mime'.trParams({'mime': result.mimeType})),
              Text(
                'convert.result.outputSize'.trParams({
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
