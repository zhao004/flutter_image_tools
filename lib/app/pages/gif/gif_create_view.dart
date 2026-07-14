import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/local_image_channel.dart';
import '../../widgets/tool_task_layout.dart';
import 'gif_controller.dart';

/// GIF 生成页，只呈现帧图片、播放速度和生成结果。
class GifCreateView extends GetView<GifController> {
  const GifCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final images = controller.selectedImages;
      final result = controller.result.value;
      return AdaptiveTaskScaffold(
        title: 'gif.hub.create.title'.tr,
        primary: ToolTaskSection(
          title: 'gif.image.title'.tr,
          description: images.isEmpty
              ? 'gif.image.empty'.tr
              : 'gif.image.selectedCount'.trParams({
                  'count': images.length.toString(),
                }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  images.isEmpty
                      ? 'gif.action.pickImages'.tr
                      : 'gif.action.repickImages'.tr,
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'gif.image.totalSize'.trParams({
                    'size': controller.formatBytes(controller.totalSizeBytes),
                  }),
                ),
                const SizedBox(height: 8),
                ...images
                    .take(8)
                    .toList()
                    .asMap()
                    .entries
                    .map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${entry.key + 1}')),
                        title: Text(
                          entry.value.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          controller.formatBytes(entry.value.sizeBytes),
                        ),
                      ),
                    ),
                if (images.length > 8)
                  Text(
                    'gif.image.moreCount'.trParams({
                      'count': (images.length - 8).toString(),
                    }),
                  ),
              ],
            ],
          ),
        ),
        secondary: ToolTaskSection(
          title: 'gif.speed.title'.tr,
          description: 'gif.speed.hint'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'gif.speed.delay'.trParams({
                  'delay': controller.delayMs.value.toString(),
                }),
              ),
              Slider(
                value: controller.delayMs.value.toDouble(),
                min: LocalImageChannel.minGifDelayMs.toDouble(),
                max: LocalImageChannel.maxGifDelayMs.toDouble(),
                divisions: 39,
                label: '${controller.delayMs.value} ms',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateDelay,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.createGif,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gif_box_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'gif.action.creating'.tr
                      : 'gif.action.create'.tr,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 24),
                Text(
                  'gif.result.title'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'gif.result.frameCountFrames'.trParams({
                    'count': result.frameCount.toString(),
                  }),
                ),
                Text(
                  'gif.result.outputDimensions'.trParams({
                    'width': result.width.toString(),
                    'height': result.height.toString(),
                  }),
                ),
                Text(
                  'gif.result.outputSize'.trParams({
                    'size': controller.formatBytes(result.outputSizeBytes),
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
