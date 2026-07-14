import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/tool_task_layout.dart';
import 'exif_controller.dart';

/// EXIF 管理页，以图片预览和元数据主从布局替代纵向卡片堆叠。
///
/// 构建设计：删除动作明确命名为“删除 EXIF”，不会覆盖原图；页面不再使用
/// “保存到相册”作为按钮文案。读取、清理和导出异常仍由控制器统一处理。
class ExifView extends GetView<ExifController> {
  const ExifView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final info = controller.exifInfo.value;
      final cleaned = controller.cleanedResult.value;
      return AdaptiveTaskScaffold(
        title: 'exif.title'.tr,
        actions: [
          if (image != null)
            IconButton(
              tooltip: 'exif.action.refresh'.tr,
              onPressed: controller.isBusy.value
                  ? null
                  : controller.refreshExif,
              icon: const Icon(Icons.refresh),
            ),
        ],
        primary: ToolTaskSection(
          title: 'exif.image.title'.tr,
          description: image == null
              ? 'exif.image.empty'.tr
              : '${controller.formatBytes(image.sizeBytes)} · '
                    '${controller.formatDimensions(image)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (image != null) ...[
                AspectRatio(
                  aspectRatio: image.hasValidDimensions
                      ? image.width / image.height
                      : 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(image.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  image.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 16),
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
                  image == null
                      ? 'exif.action.pickImage'.tr
                      : 'exif.action.repickImage'.tr,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('exif-remove-action'),
                onPressed: image == null || controller.isBusy.value
                    ? null
                    : controller.removeExif,
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text('exif.action.remove'.tr),
              ),
              if (cleaned != null) ...[
                const SizedBox(height: 24),
                Text(
                  'exif.result.title'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'exif.result.outputSize'.trParams({
                    'size': controller.formatBytes(cleaned.outputSizeBytes),
                  }),
                ),
                const SizedBox(height: 8),
                SelectableText(cleaned.outputPath),
              ],
            ],
          ),
        ),
        secondary: ToolTaskSection(
          title: 'exif.info.title'.tr,
          description: info == null
              ? 'exif.info.empty'.tr
              : !info.hasExif
              ? 'exif.info.notFound'.tr
              : null,
          child: info == null || !info.hasExif
              ? const SizedBox.shrink()
              : Column(
                  children: info.attributes.entries
                      .map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key),
                          subtitle: SelectableText(entry.value),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      );
    });
  }
}
