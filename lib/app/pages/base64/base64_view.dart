import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/tool_task_layout.dart';
import 'base64_controller.dart';

/// Base64 转换页，一次只呈现编码或解码流程并限制大文本渲染量。
class Base64View extends GetView<Base64Controller> {
  const Base64View({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isEncode = controller.mode.value == Base64Mode.encode;
      return AdaptiveTaskScaffold(
        title: 'base64.title'.tr,
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<Base64Mode>(
              segments: [
                ButtonSegment(
                  value: Base64Mode.encode,
                  icon: const Icon(Icons.code),
                  label: Text('base64.encode.title'.tr),
                ),
                ButtonSegment(
                  value: Base64Mode.decode,
                  icon: const Icon(Icons.image_outlined),
                  label: Text('base64.decode.title'.tr),
                ),
              ],
              selected: {controller.mode.value},
              onSelectionChanged: controller.isBusy.value
                  ? null
                  : (values) => controller.setMode(values.first),
            ),
            const SizedBox(height: 24),
            if (isEncode)
              _EncodeInput(controller: controller)
            else
              _DecodeInput(controller: controller),
          ],
        ),
        secondary: isEncode
            ? _EncodeResult(controller: controller)
            : _DecodeResult(controller: controller),
      );
    });
  }
}

class _EncodeInput extends StatelessWidget {
  const _EncodeInput({required this.controller});

  final Base64Controller controller;

  @override
  Widget build(BuildContext context) {
    final image = controller.selectedImage.value;
    return ToolTaskSection(
      title: 'base64.encode.source.title'.tr,
      description: image == null
          ? 'base64.encode.empty'.tr
          : '${image.name} · ${controller.formatBytes(image.sizeBytes)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: controller.isBusy.value ? null : controller.pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              image == null
                  ? 'base64.action.pickImage'.tr
                  : 'base64.action.repickImage'.tr,
            ),
          ),
          const SizedBox(height: 12),
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
    );
  }
}

class _EncodeResult extends StatelessWidget {
  const _EncodeResult({required this.controller});

  final Base64Controller controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.encodedResult.value;
    return ToolTaskSection(
      title: 'base64.result.title'.tr,
      description: result == null ? 'base64.result.empty'.tr : null,
      child: result == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 12),
                SelectableText(
                  controller.base64Preview,
                  key: const ValueKey('base64-short-preview'),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.copyBase64Text,
                        icon: const Icon(Icons.copy_outlined),
                        label: Text('base64.action.copyText'.tr),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: controller.isBusy.value
                            ? null
                            : controller.exportBase64Text,
                        icon: const Icon(Icons.description_outlined),
                        label: Text('base64.action.exportTxt'.tr),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _DecodeInput extends StatelessWidget {
  const _DecodeInput({required this.controller});

  final Base64Controller controller;

  @override
  Widget build(BuildContext context) {
    return ToolTaskSection(
      title: 'base64.decode.input.title'.tr,
      description: 'base64.decode.input.description'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller.inputController,
            enabled: !controller.isBusy.value,
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(hintText: 'base64.decode.hint'.tr),
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
        ],
      ),
    );
  }
}

class _DecodeResult extends StatelessWidget {
  const _DecodeResult({required this.controller});

  final Base64Controller controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.decodedResult.value;
    return ToolTaskSection(
      title: 'base64.decode.result.title'.tr,
      description: result == null ? 'base64.decode.result.empty'.tr : null,
      child: result == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(result.outputPath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black12,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'base64.result.outputSize'.trParams({
                    'size': controller.formatBytes(result.outputSizeBytes),
                  }),
                ),
                Text('MIME: ${result.mimeType}'),
                const SizedBox(height: 8),
                SelectableText(result.outputPath),
              ],
            ),
    );
  }
}
