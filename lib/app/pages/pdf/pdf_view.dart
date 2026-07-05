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
      appBar: AppBar(title: const Text('PDF 工具')),
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
                label: Text(controller.isBusy.value ? '生成中' : '图片转 PDF'),
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
              Text('PDF 转图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (pdf == null)
                const Text('请选择一个 PDF 文件，并输入要导出的页码。')
              else ...[
                Text(pdf.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('文件大小：${controller.formatBytes(pdf.sizeBytes)}'),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value ? null : controller.pickPdf,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(pdf == null ? '选择 PDF' : '重新选择 PDF'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.pageNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '导出页码',
                  helperText: '页码从 1 开始，超出页数会提示错误。',
                  border: OutlineInputBorder(),
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
                    label: Text(controller.isBusy.value ? '导出中' : '导出指定页'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.exportAllPdfPages,
                    icon: const Icon(Icons.collections_outlined),
                    label: const Text('导出全部页面'),
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
              Text('全部页面结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('源文件：${result.sourceName}'),
              Text('页数：${result.pageCount} 页'),
              Text(
                '总大小：${controller.formatBytes(result.totalOutputSizeBytes)}',
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
                Text('还有 ${result.outputPaths.length - 3} 个文件'),
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
              Text('页面图片结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('源文件：${result.sourceName}'),
              Text('页码：${result.pageNumber} / ${result.pageCount}'),
              Text('尺寸：${result.width} × ${result.height}'),
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
              Text('选择图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (images.isEmpty)
                const Text('请选择 1 到 50 张图片，每张图片会生成一个 PDF 页面。')
              else ...[
                Text('已选择 ${images.length} 张图片'),
                const SizedBox(height: 4),
                Text(
                  '总大小：${controller.formatBytes(controller.totalSizeBytes)}',
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(images.isEmpty ? '批量选择' : '重新选择'),
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
                if (images.length > 8) Text('还有 ${images.length - 8} 张图片'),
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
              Text('页面设置', style: Theme.of(context).textTheme.titleMedium),
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
                      (item) =>
                          ButtonSegment(value: item, label: Text(item.label)),
                    )
                    .toList(growable: false),
                selected: {controller.orientation.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setOrientation(values.first),
              ),
              const SizedBox(height: 12),
              const Text('图片会等比缩放并居中放入页面，默认保留白边避免裁切内容。'),
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
              Text('PDF 结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('页数：${result.pageCount} 页'),
              Text(
                '页面：${result.pageSize.toUpperCase()} / ${result.orientation}',
              ),
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
