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
      appBar: AppBar(title: const Text('GIF 工具')),
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
                label: Text(controller.isBusy.value ? '生成中' : '生成 GIF'),
              ),
            ),
            const SizedBox(height: 16),
            _ResultCard(controller: controller),
          ],
        ),
      ),
    );
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
              Text('选择帧图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (images.isEmpty)
                const Text('请选择 2 到 30 张图片，系统选择顺序会作为 GIF 帧顺序。')
              else ...[
                Text('已选择 ${images.length} 张图片'),
                const SizedBox(height: 4),
                Text(
                  '总大小：${controller.formatBytes(controller.totalSizeBytes)}',
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(images.isEmpty ? '批量选择' : '重新选择'),
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
                if (images.length > 8) Text('还有 ${images.length - 8} 张图片'),
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
              Text('播放速度', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('每帧间隔：${controller.delayMs.value} ms'),
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
              const Text('较小间隔播放更快；导出时所有帧会缩放到第一张图片尺寸。'),
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
              Text('GIF 结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('帧数：${result.frameCount} 帧'),
              Text('帧间隔：${result.delayMs} ms'),
              Text('输出尺寸：${result.width} × ${result.height} px'),
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

/// GIF 页面的显示边界常量，避免视图层依赖平台通道实现细节。
class LocalImageChannelLimits {
  const LocalImageChannelLimits._();

  static const int minGifDelayMs = 50;
  static const int maxGifDelayMs = 2000;
}
