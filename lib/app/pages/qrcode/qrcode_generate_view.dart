import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/tool_task_layout.dart';
import 'qrcode_controller.dart';

/// 二维码和条形码生成页，通过模式切换复用输入与主操作。
class QrcodeGenerateView extends GetView<QrcodeController> {
  const QrcodeGenerateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return AdaptiveTaskScaffold(
        title: 'qrcode.hub.generate.title'.tr,
        primary: ToolTaskSection(
          title: 'qrcode.generate.content.title'.tr,
          description: 'qrcode.generate.helper'.trParams({
            'qrBytes': '${QrcodeController.maxContentBytes}',
            'barcodeChars': '${QrcodeController.maxBarcodeLength}',
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<QrcodeGenerateMode>(
                segments: [
                  ButtonSegment(
                    value: QrcodeGenerateMode.qrCode,
                    icon: const Icon(Icons.qr_code_2),
                    label: Text('qrcode.generate.mode.qr'.tr),
                  ),
                  ButtonSegment(
                    value: QrcodeGenerateMode.barcode,
                    icon: const Icon(Icons.view_week_outlined),
                    label: Text('qrcode.generate.mode.barcode'.tr),
                  ),
                ],
                selected: {controller.generateMode.value},
                onSelectionChanged: controller.isBusy.value
                    ? null
                    : (values) => controller.setGenerateMode(values.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller.inputController,
                enabled: !controller.isBusy.value,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'qrcode.generate.hint'.tr,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.generateSelectedCode,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        controller.generateMode.value ==
                                QrcodeGenerateMode.qrCode
                            ? Icons.qr_code_2
                            : Icons.view_week_outlined,
                      ),
                label: Text(
                  controller.isBusy.value
                      ? 'qrcode.action.generating'.tr
                      : 'qrcode.action.generate'.tr,
                ),
              ),
            ],
          ),
        ),
        secondary: ToolTaskSection(
          title: 'qrcode.generate.preview.title'.tr,
          description:
              controller.result.value == null &&
                  controller.barcodeResult.value == null
              ? 'qrcode.generate.preview.empty'.tr
              : null,
          child: _GeneratedCodeResult(controller: controller),
        ),
      );
    });
  }
}

class _GeneratedCodeResult extends StatelessWidget {
  const _GeneratedCodeResult({required this.controller});

  final QrcodeController controller;

  @override
  Widget build(BuildContext context) {
    final qr = controller.result.value;
    final barcode = controller.barcodeResult.value;
    final path = qr?.outputPath ?? barcode?.outputPath;
    if (path == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: qr != null ? 1 : 2.6,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 56),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (qr != null) ...[
          Text('qrcode.result.version'.trParams({'version': '${qr.version}'})),
          Text(
            'qrcode.result.modules'.trParams({'count': '${qr.moduleCount}'}),
          ),
          Text(
            'qrcode.result.outputSize'.trParams({
              'size': controller.formatBytes(qr.outputSizeBytes),
            }),
          ),
        ] else if (barcode != null) ...[
          Text('qrcode.result.format'.trParams({'format': barcode.format})),
          Text(
            'qrcode.result.pixels'.trParams({
              'width': '${barcode.pixelWidth}',
              'height': '${barcode.pixelHeight}',
            }),
          ),
          Text(
            'qrcode.result.outputSize'.trParams({
              'size': controller.formatBytes(barcode.outputSizeBytes),
            }),
          ),
        ],
        const SizedBox(height: 8),
        SelectableText(path),
      ],
    );
  }
}
