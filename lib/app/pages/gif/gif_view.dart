import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'gif_controller.dart';

/// GIF 工具页，支持多张图片按固定帧间隔离线生成动图。
///
/// 构建设计：当前版本保持确定性输入顺序和统一延迟，先保证离线生成闭环；
/// 后续可在同一页面扩展拖拽排序、逐帧延迟和 GIF 拆帧。
class GifView extends GetView<GifController> {
  const GifView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('gif.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePickerCard(controller: controller),
            const SizedBox(height: 16),
            _DelayCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
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
            ),
            const SizedBox(height: 16),
            _ResultCard(controller: controller),
            const SizedBox(height: 24),
            _FrameExportCard(controller: controller),
            const SizedBox(height: 16),
            _FrameExportResultCard(controller: controller),
            const SizedBox(height: 24),
            _CompressCard(controller: controller),
            const SizedBox(height: 16),
            _CompressedResultCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _CompressCard extends StatelessWidget {
  const _CompressCard({required this.controller});

  final GifController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final gif = controller.selectedGif.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'gif.compress.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (gif == null)
                Text('gif.compress.empty'.tr)
              else ...[
                Text(gif.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  'gif.result.originalSize'.trParams({
                    'size': controller.formatBytes(gif.sizeBytes),
                  }),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'gif.compress.scale'.trParams({
                  'scale': controller.compressScalePercent.value.toString(),
                }),
              ),
              Slider(
                value: controller.compressScalePercent.value.toDouble(),
                min: LocalImageChannelLimits.minGifScalePercent.toDouble(),
                max: LocalImageChannelLimits.maxGifScalePercent.toDouble(),
                divisions: 15,
                label: '${controller.compressScalePercent.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateCompressScale,
              ),
              const SizedBox(height: 12),
              Text(
                'gif.compress.frameStep'.trParams({
                  'step': controller.compressFrameStepMs.value.toString(),
                }),
              ),
              Slider(
                value: controller.compressFrameStepMs.value.toDouble(),
                min: LocalImageChannelLimits.minGifFrameStepMs.toDouble(),
                max: LocalImageChannelLimits.maxGifFrameStepMs.toDouble(),
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
            ],
          );
        }),
      ),
    );
  }
}

class _CompressedResultCard extends StatelessWidget {
  const _CompressedResultCard({required this.controller});

  final GifController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.compressedGif.value;
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
                'gif.compressedResult.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'gif.result.frameCountFrames'.trParams({
                  'count': result.frameCount.toString(),
                }),
              ),
              Text(
                'gif.result.dimensions'.trParams({
                  'width': result.width.toString(),
                  'height': result.height.toString(),
                }),
              ),
              Text(
                'gif.result.scale'.trParams({
                  'scale': result.scalePercent.toString(),
                }),
              ),
              Text(
                'gif.result.frameStep'.trParams({
                  'step': result.frameStepMs.toString(),
                }),
              ),
              Text(
                'gif.result.originalSize'.trParams({
                  'size': controller.formatBytes(result.originalSizeBytes),
                }),
              ),
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

class _FrameExportCard extends StatelessWidget {
  const _FrameExportCard({required this.controller});

  final GifController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final gif = controller.selectedGif.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'gif.frames.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (gif == null)
                Text('gif.frames.empty'.tr)
              else ...[
                Text(gif.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  'gif.frames.fileSize'.trParams({
                    'size': controller.formatBytes(gif.sizeBytes),
                  }),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value ? null : controller.pickGif,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  gif == null
                      ? 'gif.action.pickGif'.tr
                      : 'gif.action.repickGif'.tr,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'gif.frames.frameStep'.trParams({
                  'step': controller.frameStepMs.value.toString(),
                }),
              ),
              Slider(
                value: controller.frameStepMs.value.toDouble(),
                min: LocalImageChannelLimits.minGifFrameStepMs.toDouble(),
                max: LocalImageChannelLimits.maxGifFrameStepMs.toDouble(),
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
            ],
          );
        }),
      ),
    );
  }
}

class _FrameExportResultCard extends StatelessWidget {
  const _FrameExportResultCard({required this.controller});

  final GifController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.framesExport.value;
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
                'gif.framesResult.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'gif.framesResult.frameCount'.trParams({
                  'count': result.frameCount.toString(),
                }),
              ),
              Text(
                'gif.framesResult.duration'.trParams({
                  'duration': result.durationMs.toString(),
                }),
              ),
              Text(
                'gif.frames.frameStep'.trParams({
                  'step': result.frameStepMs.toString(),
                }),
              ),
              Text(
                'gif.result.dimensions'.trParams({
                  'width': result.width.toString(),
                  'height': result.height.toString(),
                }),
              ),
              Text(
                'gif.result.totalSize'.trParams({
                  'size': controller.formatBytes(result.totalOutputSizeBytes),
                }),
              ),
              const SizedBox(height: 8),
              Text(
                result.outputDirectory,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              ...result.outputPaths
                  .take(3)
                  .map(
                    (path) => Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              if (result.outputPaths.length > 3)
                Text(
                  'gif.framesResult.moreFiles'.trParams({
                    'count': (result.outputPaths.length - 3).toString(),
                  }),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({required this.controller});

  final GifController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final images = controller.selectedImages;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'gif.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (images.isEmpty)
                Text('gif.image.empty'.tr)
              else ...[
                Text(
                  'gif.image.selectedCount'.trParams({
                    'count': images.length.toString(),
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  'gif.image.totalSize'.trParams({
                    'size': controller.formatBytes(controller.totalSizeBytes),
                  }),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
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
                const SizedBox(height: 12),
                ...images
                    .take(8)
                    .map(
                      (image) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          image.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          );
        }),
      ),
    );
  }
}

class _DelayCard extends StatelessWidget {
  const _DelayCard({required this.controller});

  final GifController controller;

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
                'gif.speed.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'gif.speed.delay'.trParams({
                  'delay': controller.delayMs.value.toString(),
                }),
              ),
              Slider(
                value: controller.delayMs.value.toDouble(),
                min: LocalImageChannelLimits.minGifDelayMs.toDouble(),
                max: LocalImageChannelLimits.maxGifDelayMs.toDouble(),
                divisions: 39,
                label: '${controller.delayMs.value} ms',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateDelay,
              ),
              Text('gif.speed.hint'.tr),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller});

  final GifController controller;

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
                'gif.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'gif.result.frameCountFrames'.trParams({
                  'count': result.frameCount.toString(),
                }),
              ),
              Text(
                'gif.result.delay'.trParams({
                  'delay': result.delayMs.toString(),
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

/// GIF 页面的显示边界常量，避免视图层依赖平台通道实现细节。
class LocalImageChannelLimits {
  const LocalImageChannelLimits._();

  static const int minGifDelayMs = 50;
  static const int maxGifDelayMs = 2000;
  static const int minGifFrameStepMs = 50;
  static const int maxGifFrameStepMs = 1000;
  static const int minGifScalePercent = 25;
  static const int maxGifScalePercent = 100;
}
