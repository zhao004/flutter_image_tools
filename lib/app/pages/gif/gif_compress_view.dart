import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/local_image_channel.dart';
import '../../widgets/tool_task_layout.dart';
import 'gif_controller.dart';

/// GIF 压缩页，将源文件预览与压缩参数分置在自适应双栏中。
class GifCompressView extends GetView<GifController> {
  const GifCompressView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final gif = controller.selectedGif.value;
      final result = controller.compressedGif.value;
      return AdaptiveTaskScaffold(
        title: 'gif.hub.compress.title'.tr,
        primary: ToolTaskSection(
          title: 'gif.compress.source.title'.tr,
          description: gif == null
              ? 'gif.compress.empty'.tr
              : 'gif.result.originalSize'.trParams({
                  'size': controller.formatBytes(gif.sizeBytes),
                }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (gif != null) ...[
                AspectRatio(
                  aspectRatio: gif.hasValidDimensions
                      ? gif.width / gif.height
                      : 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(gif.path),
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
                Text(gif.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.isBusy.value ? null : controller.pickGif,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  gif == null
                      ? 'gif.action.pickGif'.tr
                      : 'gif.action.repickGif'.tr,
                ),
              ),
            ],
          ),
        ),
        secondary: ToolTaskSection(
          title: 'gif.compress.options.title'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'gif.compress.scale'.trParams({
                  'scale': controller.compressScalePercent.value.toString(),
                }),
              ),
              Slider(
                value: controller.compressScalePercent.value.toDouble(),
                min: LocalImageChannel.minGifScalePercent.toDouble(),
                max: LocalImageChannel.maxGifScalePercent.toDouble(),
                divisions: 15,
                label: '${controller.compressScalePercent.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateCompressScale,
              ),
              Text(
                'gif.compress.frameStep'.trParams({
                  'step': controller.compressFrameStepMs.value.toString(),
                }),
              ),
              Slider(
                value: controller.compressFrameStepMs.value.toDouble(),
                min: LocalImageChannel.minGifFrameStepMs.toDouble(),
                max: LocalImageChannel.maxGifFrameStepMs.toDouble(),
                divisions: 19,
                label: '${controller.compressFrameStepMs.value} ms',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateCompressFrameStep,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.compressSelectedGif,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compress),
                label: Text(
                  controller.isBusy.value
                      ? 'gif.action.compressing'.tr
                      : 'gif.action.compress'.tr,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 24),
                Text(
                  'gif.compressedResult.title'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'gif.result.outputSize'.trParams({
                    'size': controller.formatBytes(result.outputSizeBytes),
                  }),
                ),
                Text(
                  'gif.result.saved'.trParams({
                    'percent': controller.formatPercent(result.savedRatio),
                  }),
                ),
                const SizedBox(height: 8),
                SelectableText(result.outputPath),
              ],
            ],
          ),
        ),
      );
    });
  }
}
