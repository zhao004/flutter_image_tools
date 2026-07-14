import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../widgets/tool_task_layout.dart';
import 'pdf_controller.dart';

/// PDF 转图片页面，通过单一模式选择避免重复的导出按钮和结果区域。
class PdfExportView extends GetView<PdfController> {
  const PdfExportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pdf = controller.selectedPdf.value;
      return AdaptiveTaskScaffold(
        title: 'pdf.hub.export.title'.tr,
        primary: ToolTaskSection(
          title: 'pdf.export.source.title'.tr,
          description: pdf == null
              ? 'pdf.export.empty'.tr
              : 'pdf.export.fileSize'.trParams({
                  'size': controller.formatBytes(pdf.sizeBytes),
                }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pdf != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(
                    pdf.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: controller.isBusy.value ? null : controller.pickPdf,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  pdf == null
                      ? 'pdf.action.pickPdf'.tr
                      : 'pdf.action.repickPdf'.tr,
                ),
              ),
            ],
          ),
        ),
        secondary: ToolTaskSection(
          title: 'pdf.export.options.title'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<PdfExportMode>(
                segments: PdfExportMode.values
                    .map(
                      (mode) => ButtonSegment(
                        value: mode,
                        label: Text(mode.labelKey.tr),
                      ),
                    )
                    .toList(growable: false),
                selected: {controller.exportMode.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setExportMode(values.first),
              ),
              if (controller.exportMode.value == PdfExportMode.singlePage) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: controller.pageNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !controller.isBusy.value,
                  decoration: InputDecoration(
                    labelText: 'pdf.export.pageNumber'.tr,
                    helperText: 'pdf.export.pageNumberHelp'.tr,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.exportPdfImages,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'pdf.action.exporting'.tr
                      : 'pdf.action.export'.tr,
                ),
              ),
              const SizedBox(height: 8),
              _PdfExportResult(controller: controller),
            ],
          ),
        ),
      );
    });
  }
}

class _PdfExportResult extends StatelessWidget {
  const _PdfExportResult({required this.controller});

  final PdfController controller;

  @override
  Widget build(BuildContext context) {
    final page = controller.pageImageResult.value;
    final allPages = controller.allPagesResult.value;
    if (page == null && allPages == null) {
      return const SizedBox.shrink();
    }
    if (page != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'pdf.pageImageResult.title'.tr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'pdf.pageImageResult.pageNumber'.trParams({
              'page': page.pageNumber.toString(),
              'total': page.pageCount.toString(),
            }),
          ),
          Text(
            'pdf.pageImageResult.dimensions'.trParams({
              'width': page.width.toString(),
              'height': page.height.toString(),
            }),
          ),
          Text(
            'pdf.result.outputSize'.trParams({
              'size': controller.formatBytes(page.outputSizeBytes),
            }),
          ),
          const SizedBox(height: 8),
          SelectableText(page.outputPath),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'pdf.allPagesResult.title'.tr,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'pdf.result.pageCount'.trParams({
            'count': allPages!.pageCount.toString(),
          }),
        ),
        Text(
          'pdf.result.totalSize'.trParams({
            'size': controller.formatBytes(allPages.totalOutputSizeBytes),
          }),
        ),
        const SizedBox(height: 8),
        SelectableText(allPages.outputDirectory),
      ],
    );
  }
}
