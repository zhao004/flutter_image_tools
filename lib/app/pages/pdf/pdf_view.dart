import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pdf_controller.dart';

/// PDF 工具页，支持多张图片离线生成 PDF。
///
/// 构建设计：每张图片对应一个 PDF 页面，页面规格和方向统一设置；当前版本
/// 先保证图片转 PDF 稳定闭环，PDF 转图片和指定页面导出后续扩展。
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
          ],
        ),
      ),
    );
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
