import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'filter_controller.dart';

/// 图片滤镜页，支持灰度、黑白、怀旧、反色、冷暖色、HDR、胶片、锐化和柔化。
///
/// 构建设计：当前阶段提供确定性像素滤镜，不引入预览缓存；后续可扩展为
/// 缩略图预览和强度调节。
class FilterView extends GetView<FilterController> {
  const FilterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('filter.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _FilterCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.applyFilter,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.filter_vintage_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'common.processing'.tr
                      : 'filter.action.apply'.tr,
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

  final FilterController controller;

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
                'filter.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                Text('filter.image.empty'.tr)
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
                      ? 'filter.action.pickImage'.tr
                      : 'filter.action.repickImage'.tr,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({required this.controller});

  final FilterController controller;

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
                'filter.type.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ImageFilterType.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.filter.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setFilter(item),
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

  final FilterController controller;

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
                'filter.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'filter.result.type'.trParams({
                  'type': controller.labelForFilterValue(result.filter),
                }),
              ),
              Text(
                'filter.result.outputSize'.trParams({
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
