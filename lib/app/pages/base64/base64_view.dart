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
      appBar: AppBar(title: const Text('Base64')),
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
                '图片转 Base64',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                const Text('请选择一张本地图片生成 Base64 文本，单文件最大 12 MB。')
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
                    label: Text(image == null ? '选择图片' : '重新选择'),
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
                    label: Text(controller.isBusy.value ? '处理中' : '生成文本'),
                  ),
                ],
              ),
              if (result != null) ...[
                const SizedBox(height: 12),
                Text(
                  '文本长度：${controller.formatTextLength(result.base64Length)}',
                ),
                Text('来源 MIME：${result.mimeType}'),
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
                      label: const Text('复制文本'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy.value
                          ? null
                          : controller.exportBase64Text,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('导出 TXT'),
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
                'Base64 转图片',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.inputController,
                enabled: !controller.isBusy.value,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '粘贴 Base64 文本或 data:image/png;base64,...',
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
                label: Text(controller.isBusy.value ? '还原中' : '还原图片'),
              ),
              if (result != null) ...[
                const SizedBox(height: 12),
                Text('导出大小：${controller.formatBytes(result.outputSizeBytes)}'),
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
