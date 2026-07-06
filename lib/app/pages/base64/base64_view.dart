import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'base64_controller.dart';

/// Base64 工具页，支持图片转文本、复制、导出文本和文本还原图片。
///
/// 构建设计：页面分成编码和解码两个独立卡片，避免用户在同一流程中混淆
/// 图片输入与文本输入；大文件边界由控制器统一处理。
class Base64View extends GetView<Base64Controller> {
  const Base64View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('base64.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _EncodeCard(controller: controller),
            const SizedBox(height: 16),
            _DecodeCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _EncodeCard extends StatelessWidget {
  const _EncodeCard({required this.controller});

  final Base64Controller controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final image = controller.selectedImage.value;
          final result = controller.encodedResult.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'base64.encode.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                Text('base64.encode.empty'.tr)
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      image == null
                          ? 'base64.action.pickImage'.tr
                          : 'base64.action.repickImage'.tr,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.encodeSelectedImage,
                    icon: controller.isBusy.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.code),
                    label: Text(
                      controller.isBusy.value
                          ? 'common.processing'.tr
                          : 'base64.action.encode'.tr,
                    ),
                  ),
                ],
              ),
              if (result != null) ...[
                const SizedBox(height: 12),
                Text(
                  'base64.result.textLength'.trParams({
                    'length': controller.formatTextLength(result.base64Length),
                  }),
                ),
                Text(
                  'base64.result.sourceMime'.trParams({
                    'mime': result.mimeType,
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.base64Text.value,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.copyBase64Text,
                      icon: const Icon(Icons.copy),
                      label: Text('base64.action.copyText'.tr),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy.value
                          ? null
                          : controller.exportBase64Text,
                      icon: const Icon(Icons.description_outlined),
                      label: Text('base64.action.exportTxt'.tr),
                    ),
                  ],
                ),
                if (result.outputPath != image?.path) ...[
                  const SizedBox(height: 8),
                  Text(
                    result.outputPath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _DecodeCard extends StatelessWidget {
  const _DecodeCard({required this.controller});

  final Base64Controller controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final result = controller.decodedResult.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'base64.decode.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.inputController,
                enabled: !controller.isBusy.value,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'base64.decode.hint'.tr,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.decodeInputText,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'base64.action.decoding'.tr
                      : 'base64.action.decode'.tr,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 12),
                Text(
                  'base64.result.outputSize'.trParams({
                    'size': controller.formatBytes(result.outputSizeBytes),
                  }),
                ),
                Text('MIME：${result.mimeType}'),
                const SizedBox(height: 8),
                Text(
                  result.outputPath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}
