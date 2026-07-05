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
      appBar: AppBar(title: const Text('二维码')),
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
              Text('识别二维码/条形码', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (image == null)
                const Text('请选择包含二维码或条形码的图片，识别过程完全在本地完成。')
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('尺寸：${image.width} × ${image.height} px'),
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
                label: Text(image == null ? '选择并识别' : '重新选择并识别'),
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
              Text('识别结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('格式：${result.format}'),
              Text('内容长度：${result.text.length} 字符'),
              if (result.rawBytesLength > 0)
                Text('原始字节：${result.rawBytesLength}'),
              const SizedBox(height: 8),
              SelectableText(result.text),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.copyScanText,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('复制内容'),
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
              Text('生成二维码/条形码', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller.inputController,
                enabled: !controller.isBusy.value,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '输入文本、链接或短备注',
                  helperText:
                      '二维码最多 ${QrcodeController.maxContentBytes} 字节；条形码最多 ${QrcodeController.maxBarcodeLength} 个可打印 ASCII 字符。',
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
                    label: Text(controller.isBusy.value ? '生成中' : '生成二维码'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.generateBarcode,
                    icon: const Icon(Icons.view_week_outlined),
                    label: const Text('生成条形码'),
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
              Text('条形码结果', style: Theme.of(context).textTheme.titleMedium),
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
              Text('格式：${result.format}'),
              Text('像素：${result.pixelWidth} × ${result.pixelHeight}'),
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
              Text('二维码结果', style: Theme.of(context).textTheme.titleMedium),
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
              Text('版本：${result.version}'),
              Text('模块：${result.moduleCount} × ${result.moduleCount}'),
              Text('像素：${result.pixelSize} × ${result.pixelSize}'),
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
