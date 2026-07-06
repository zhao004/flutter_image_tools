import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'exif_controller.dart';

/// EXIF 管理页，支持本地读取拍摄信息并导出去除 EXIF 的图片副本。
///
/// 构建设计：读取和删除共用同一张选中图片；删除不会覆盖原图，降低隐私清理
/// 的误操作风险，同时保留输出路径供用户后续查找。
class ExifView extends GetView<ExifController> {
  const ExifView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('exif.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _AttributesCard(controller: controller),
            const SizedBox(height: 16),
            _CleanResultCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.controller});

  final ExifController controller;

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
                'exif.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                Text('exif.image.empty'.tr)
              else ...[
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
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.pickImage,
                    icon: controller.isBusy.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      controller.isBusy.value
                          ? 'common.processing'.tr
                          : image == null
                          ? 'exif.action.pickImage'.tr
                          : 'exif.action.repickImage'.tr,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.refreshExif,
                    icon: const Icon(Icons.refresh),
                    label: Text('exif.action.refresh'.tr),
                  ),
                  FilledButton.icon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.removeExif,
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: Text('exif.action.remove'.tr),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _AttributesCard extends StatelessWidget {
  const _AttributesCard({required this.controller});

  final ExifController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = controller.exifInfo.value;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'exif.info.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (info == null)
                Text('exif.info.empty'.tr)
              else if (!info.hasExif)
                Text('exif.info.notFound'.tr)
              else
                ...info.attributes.entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _CleanResultCard extends StatelessWidget {
  const _CleanResultCard({required this.controller});

  final ExifController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.cleanedResult.value;
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
                'exif.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'exif.result.outputSize'.trParams({
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
