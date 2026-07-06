import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'pdf_controller.dart';

/// PDF 工具页，支持多张图片离线生成 PDF，也支持 PDF 页面导出 PNG。
///
/// 构建设计：图片转 PDF 与 PDF 转图片分为独立卡片，避免两个流程的输入
/// 状态互相影响；指定页码在 Dart 层先做整数校验，全部页面由 Android 顺序渲染。
class PdfView extends GetView<PdfController> {
  const PdfView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('pdf.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePickerCard(controller: controller),
            const SizedBox(height: 16),
            _PageOptionsCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
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
            ),
            const SizedBox(height: 16),
            _ResultCard(controller: controller),
            const SizedBox(height: 24),
            _PdfPageExportCard(controller: controller),
            const SizedBox(height: 16),
            _PageImageResultCard(controller: controller),
            const SizedBox(height: 16),
            _AllPagesResultCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _PdfPageExportCard extends StatelessWidget {
  const _PdfPageExportCard({required this.controller});

  final PdfController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final pdf = controller.selectedPdf.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'pdf.export.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (pdf == null)
                Text('pdf.export.empty'.tr)
              else ...[
                Text(pdf.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  'pdf.export.fileSize'.trParams({
                    'size': controller.formatBytes(pdf.sizeBytes),
                  }),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value ? null : controller.pickPdf,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  pdf == null
                      ? 'pdf.action.pickPdf'.tr
                      : 'pdf.action.repickPdf'.tr,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.pageNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'pdf.export.pageNumber'.tr,
                  helperText: 'pdf.export.pageNumberHelp'.tr,
                  border: const OutlineInputBorder(),
                ),
                enabled: !controller.isBusy.value,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.exportPdfPage,
                    icon: controller.isBusy.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: Text(
                      controller.isBusy.value
                          ? 'pdf.action.exporting'.tr
                          : 'common.saveToGallery'.tr,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.exportAllPdfPages,
                    icon: const Icon(Icons.collections_outlined),
                    label: Text('common.saveToGallery'.tr),
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

class _AllPagesResultCard extends StatelessWidget {
  const _AllPagesResultCard({required this.controller});

  final PdfController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.allPagesResult.value;
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
                'pdf.allPagesResult.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'pdf.result.sourceName'.trParams({'name': result.sourceName}),
              ),
              Text(
                'pdf.result.pageCount'.trParams({
                  'count': result.pageCount.toString(),
                }),
              ),
              Text(
                'pdf.result.totalSize'.trParams({
                  'size': controller.formatBytes(result.totalOutputSizeBytes),
                }),
              ),
              const SizedBox(height: 8),
              Text(
                result.outputDirectory,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              ...result.outputPaths
                  .take(3)
                  .map(
                    (path) => Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              if (result.outputPaths.length > 3)
                Text(
                  'pdf.allPagesResult.moreFiles'.trParams({
                    'count': (result.outputPaths.length - 3).toString(),
                  }),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _PageImageResultCard extends StatelessWidget {
  const _PageImageResultCard({required this.controller});

  final PdfController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.pageImageResult.value;
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
                'pdf.pageImageResult.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'pdf.result.sourceName'.trParams({'name': result.sourceName}),
              ),
              Text(
                'pdf.pageImageResult.pageNumber'.trParams({
                  'page': result.pageNumber.toString(),
                  'total': result.pageCount.toString(),
                }),
              ),
              Text(
                'pdf.pageImageResult.dimensions'.trParams({
                  'width': result.width.toString(),
                  'height': result.height.toString(),
                }),
              ),
              Text(
                'pdf.result.outputSize'.trParams({
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

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({required this.controller});

  final PdfController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final images = controller.selectedImages;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'pdf.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (images.isEmpty)
                Text('pdf.image.empty'.tr)
              else ...[
                Text(
                  'pdf.image.selectedCount'.trParams({
                    'count': images.length.toString(),
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  'pdf.image.totalSize'.trParams({
                    'size': controller.formatBytes(controller.totalSizeBytes),
                  }),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
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
                const SizedBox(height: 12),
                ...images
                    .take(8)
                    .map(
                      (image) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          image.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
          );
        }),
      ),
    );
  }
}

class _PageOptionsCard extends StatelessWidget {
  const _PageOptionsCard({required this.controller});

  final PdfController controller;

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
                'pdf.pageSettings.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Text('pdf.pageSettings.fitHint'.tr),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller});

  final PdfController controller;

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
                'pdf.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
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
