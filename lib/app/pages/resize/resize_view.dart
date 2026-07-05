import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'resize_controller.dart';

/// 图片尺寸调整页，支持按目标宽高和百分比缩放本地图片。
///
/// 构建设计：页面保持单图任务闭环，先通过原生端读取原始尺寸，再在 Dart
/// 侧处理比例联动和输入边界，降低无效参数进入图片解码流程的风险。
class ResizeView extends GetView<ResizeController> {
  const ResizeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('尺寸调整')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _SizeCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.resize,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.aspect_ratio),
                label: Text(controller.isBusy.value ? '调整中' : '开始调整'),
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
  const _ImageCard({required this.controller});

  final ResizeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final image = controller.selectedImage.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (image == null)
                const Text('请选择一张 JPG、PNG、WebP 或 BMP 图片进行本地尺寸调整。')
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
                Text(controller.formatDimensions(image)),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(image == null ? '选择图片' : '重新选择'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({required this.controller});

  final ResizeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('目标尺寸', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保持原比例'),
                value: controller.keepAspectRatio.value,
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateKeepAspectRatio,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.widthController,
                      enabled: !controller.isBusy.value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '宽度',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: controller.updateWidth,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller.heightController,
                      enabled: !controller.isBusy.value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '高度',
                        suffixText: 'px',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: controller.updateHeight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('按比例缩放：${controller.percent.value.round()}%'),
              Slider(
                value: controller.percent.value.clamp(10, 300),
                min: 10,
                max: 300,
                divisions: 58,
                label: '${controller.percent.value.round()}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updatePercent,
              ),
              const Text('支持 10% 到 300%，最大单边 10000 像素。'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller});

  final ResizeController controller;

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
              Text('调整结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('目标尺寸：${result.width} × ${result.height} px'),
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
