import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'image_watermark_controller.dart';

/// 图片水印页，支持 PNG/Logo/二维码图片作为水印叠加到底图上。
///
/// 构建设计：先提供固定位置、透明度、缩放、旋转和平铺，避免引入复杂拖拽预览；
/// 后续可在同一参数模型上扩展自由拖动和实时预览。
class ImageWatermarkView extends GetView<ImageWatermarkController> {
  const ImageWatermarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片水印')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(
              title: '选择底图',
              emptyText: '请选择需要添加图片水印的底图。',
              buttonText: '选择底图',
              selectedImage: controller.selectedImage,
              isBusy: controller.isBusy,
              onPick: controller.pickSourceImage,
              controller: controller,
            ),
            const SizedBox(height: 16),
            _ImageCard(
              title: '选择水印图片',
              emptyText: '请选择 PNG、Logo 或二维码图片作为水印。',
              buttonText: '选择水印',
              selectedImage: controller.selectedWatermark,
              isBusy: controller.isBusy,
              onPick: controller.pickWatermarkImage,
              controller: controller,
            ),
            const SizedBox(height: 16),
            _WatermarkOptionsCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.addWatermark,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.layers_outlined),
                label: Text(controller.isBusy.value ? '处理中' : '添加图片水印'),
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

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.title,
    required this.emptyText,
    required this.buttonText,
    required this.selectedImage,
    required this.isBusy,
    required this.onPick,
    required this.controller,
  });

  final String title;
  final String emptyText;
  final String buttonText;
  final Rxn selectedImage;
  final RxBool isBusy;
  final VoidCallback onPick;
  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final image = selectedImage.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (image == null)
                Text(emptyText)
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
                Text(controller.formatDimensions(image)),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isBusy.value ? null : onPick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(image == null ? buttonText : '重新选择'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _WatermarkOptionsCard extends StatelessWidget {
  const _WatermarkOptionsCard({required this.controller});

  final ImageWatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('水印配置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ImageWatermarkPosition.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.position.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setPosition(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text('透明度：${controller.opacity.value}%'),
              Slider(
                value: controller.opacity.value.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                label: '${controller.opacity.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateOpacity,
              ),
              Text('缩放：${controller.scalePercent.value}%'),
              Slider(
                value: controller.scalePercent.value.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                label: '${controller.scalePercent.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateScale,
              ),
              Text('旋转：${controller.rotationDegrees.value}°'),
              Slider(
                value: controller.rotationDegrees.value.toDouble(),
                min: -180,
                max: 180,
                divisions: 72,
                label: '${controller.rotationDegrees.value}°',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateRotation,
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

  final ImageWatermarkController controller;

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
              Text('水印结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('水印图片：${result.watermark.name}'),
              Text('位置：${result.position}'),
              Text('透明度：${result.opacity}%'),
              Text('缩放：${result.scalePercent}%'),
              Text('旋转：${result.rotationDegrees}°'),
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
