import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'qrcode_controller.dart';

/// 二维码工具页，支持文本和链接本地生成 QR Code PNG。
///
/// 构建设计：输入、生成动作和结果预览放在同一流程内；当前版本先完成生成
/// 与识别闭环；二维码和条形码都在本地生成，不上传图片或文本。
class QrcodeView extends GetView<QrcodeController> {
  const QrcodeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('qrcode.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GenerateCard(controller: controller),
            const SizedBox(height: 16),
            _ResultCard(controller: controller),
            const SizedBox(height: 16),
            _BarcodeResultCard(controller: controller),
            const SizedBox(height: 24),
            _ScanCard(controller: controller),
            const SizedBox(height: 16),
            _ScanResultCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.controller});

  final QrcodeController controller;

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
                'qrcode.scan.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                Text('qrcode.scan.empty'.tr)
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  'qrcode.result.imageSize'.trParams({
                    'width': '${image.width}',
                    'height': '${image.height}',
                  }),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickAndScanImage,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(
                  image == null
                      ? 'qrcode.action.pickScan'.tr
                      : 'qrcode.action.repickScan'.tr,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({required this.controller});

  final QrcodeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.scanResult.value;
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
                'qrcode.scan.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('qrcode.result.format'.trParams({'format': result.format})),
              Text(
                'qrcode.result.contentLength'.trParams({
                  'length': '${result.text.length}',
                }),
              ),
              if (result.rawBytesLength > 0)
                Text(
                  'qrcode.result.rawBytes'.trParams({
                    'bytes': '${result.rawBytesLength}',
                  }),
                ),
              const SizedBox(height: 8),
              SelectableText(result.text),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.copyScanText,
                icon: const Icon(Icons.copy_outlined),
                label: Text('qrcode.action.copyContent'.tr),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _GenerateCard extends StatelessWidget {
  const _GenerateCard({required this.controller});

  final QrcodeController controller;

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
                'qrcode.generate.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.inputController,
                enabled: !controller.isBusy.value,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'qrcode.generate.hint'.tr,
                  helperText: 'qrcode.generate.helper'.trParams({
                    'qrBytes': '${QrcodeController.maxContentBytes}',
                    'barcodeChars': '${QrcodeController.maxBarcodeLength}',
                  }),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.generateQrCode,
                    icon: controller.isBusy.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_2),
                    label: Text(
                      controller.isBusy.value
                          ? 'qrcode.action.generating'.tr
                          : 'common.saveToGallery'.tr,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.generateBarcode,
                    icon: const Icon(Icons.view_week_outlined),
                    label: Text('common.saveToGallery'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeResultCard extends StatelessWidget {
  const _BarcodeResultCard({required this.controller});

  final QrcodeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.barcodeResult.value;
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
                'qrcode.barcode.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.file(
                    File(result.outputPath),
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 72),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('qrcode.result.format'.trParams({'format': result.format})),
              Text(
                'qrcode.result.pixels'.trParams({
                  'width': '${result.pixelWidth}',
                  'height': '${result.pixelHeight}',
                }),
              ),
              Text(
                'qrcode.result.outputSize'.trParams({
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller});

  final QrcodeController controller;

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
                'qrcode.qr.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.file(
                    File(result.outputPath),
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 72),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'qrcode.result.version'.trParams({
                  'version': '${result.version}',
                }),
              ),
              Text(
                'qrcode.result.modules'.trParams({
                  'count': '${result.moduleCount}',
                }),
              ),
              Text(
                'qrcode.result.pixels'.trParams({
                  'width': '${result.pixelSize}',
                  'height': '${result.pixelSize}',
                }),
              ),
              Text(
                'qrcode.result.outputSize'.trParams({
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
