import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'qrcode_controller.dart';

/// 二维码工具页，支持文本和链接本地生成 QR Code PNG。
///
/// 构建设计：输入、生成动作和结果预览放在同一流程内；当前版本先完成生成
/// 闭环，识别和条形码能力后续接入原生扫描或本地解码器。
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
          ],
        ),
      ),
    );
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
              Text('生成二维码', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller.inputController,
                enabled: !controller.isBusy.value,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '输入文本、链接或短备注',
                  helperText:
                      '最多 ${QrcodeController.maxContentBytes} 字节，完全本地生成。',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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
                label: Text(controller.isBusy.value ? '生成中' : '生成 PNG'),
              ),
            ],
          ),
        ),
      ),
    );
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
