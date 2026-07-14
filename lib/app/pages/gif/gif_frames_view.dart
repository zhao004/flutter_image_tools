import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/local_image_channel.dart';
import '../../widgets/tool_task_layout.dart';
import 'gif_controller.dart';

/// GIF 拆帧页，只管理单个 GIF、采样间隔和帧导出结果。
class GifFramesView extends GetView<GifController> {
  const GifFramesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final gif = controller.selectedGif.value;
      final result = controller.framesExport.value;
      return AdaptiveTaskScaffold(
        title: 'gif.hub.frames.title'.tr,
        primary: ToolTaskSection(
          title: 'gif.frames.source.title'.tr,
          description: gif == null
              ? 'gif.frames.empty'.tr
              : 'gif.frames.fileSize'.trParams({
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
          title: 'gif.frames.options.title'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'gif.frames.frameStep'.trParams({
                  'step': controller.frameStepMs.value.toString(),
                }),
              ),
              Slider(
                value: controller.frameStepMs.value.toDouble(),
                min: LocalImageChannel.minGifFrameStepMs.toDouble(),
                max: LocalImageChannel.maxGifFrameStepMs.toDouble(),
                divisions: 19,
                label: '${controller.frameStepMs.value} ms',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateFrameStep,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.exportFrames,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.burst_mode_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'gif.action.exporting'.tr
                      : 'gif.action.exportFrames'.tr,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 24),
                Text(
                  'gif.framesResult.title'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'gif.framesResult.frameCount'.trParams({
                    'count': result.frameCount.toString(),
                  }),
                ),
                Text(
                  'gif.result.totalSize'.trParams({
                    'size': controller.formatBytes(result.totalOutputSizeBytes),
                  }),
                ),
                const SizedBox(height: 8),
                SelectableText(result.outputDirectory),
              ],
            ],
          ),
        ),
      );
    });
  }
}
