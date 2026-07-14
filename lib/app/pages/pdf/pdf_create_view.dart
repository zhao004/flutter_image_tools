import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/tool_task_layout.dart';
import 'pdf_controller.dart';

/// 图片转 PDF 页面，集中处理图片输入、页面参数和单一生成动作。
class PdfCreateView extends GetView<PdfController> {
  const PdfCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final images = controller.selectedImages;
      final result = controller.result.value;
      return AdaptiveTaskScaffold(
        title: 'pdf.hub.create.title'.tr,
        primary: ToolTaskSection(
          title: 'pdf.image.title'.tr,
          description: images.isEmpty
              ? 'pdf.image.empty'.tr
              : 'pdf.image.selectedCount'.trParams({
                  'count': images.length.toString(),
                }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  images.isEmpty
                      ? 'pdf.action.pickImages'.tr
                      : 'pdf.action.repickImages'.tr,
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'pdf.image.totalSize'.trParams({
                    'size': controller.formatBytes(controller.totalSizeBytes),
                  }),
                ),
                const SizedBox(height: 8),
                ...images
                    .take(8)
                    .map(
                      (image) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.image_outlined),
                        title: Text(
                          image.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(controller.formatBytes(image.sizeBytes)),
                      ),
                    ),
                if (images.length > 8)
                  Text(
                    'pdf.image.moreCount'.trParams({
                      'count': (images.length - 8).toString(),
                    }),
                  ),
              ],
            ],
          ),
        ),
        secondary: ToolTaskSection(
          title: 'pdf.pageSettings.title'.tr,
          description: 'pdf.pageSettings.fitHint'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<PdfPageSize>(
                segments: PdfPageSize.values
                    .map(
                      (item) =>
                          ButtonSegment(value: item, label: Text(item.label)),
                    )
                    .toList(growable: false),
                selected: {controller.pageSize.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setPageSize(values.first),
              ),
              const SizedBox(height: 12),
              SegmentedButton<PdfOrientation>(
                segments: PdfOrientation.values
                    .map(
                      (item) => ButtonSegment(
                        value: item,
                        label: Text(item.labelKey.tr),
                      ),
                    )
                    .toList(growable: false),
                selected: {controller.orientation.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setOrientation(values.first),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.createPdf,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'pdf.action.creating'.tr
                      : 'pdf.action.create'.tr,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 24),
                Text(
                  'pdf.result.title'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'pdf.result.pageCount'.trParams({
                    'count': result.pageCount.toString(),
                  }),
                ),
                Text(
                  'pdf.result.page'.trParams({
                    'pageSize': result.pageSize.toUpperCase(),
                    'orientation': controller.orientationLabel(
                      result.orientation,
                    ),
                  }),
                ),
                Text(
                  'pdf.result.outputSize'.trParams({
                    'size': controller.formatBytes(result.outputSizeBytes),
                  }),
                ),
                const SizedBox(height: 8),
                SelectableText(result.outputPath),
              ],
            ],
          ),
        ),
      );
    });
  }
}
