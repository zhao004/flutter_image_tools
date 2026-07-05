import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'compress_controller.dart';

/// 图片压缩页，提供单图选择、质量调节、执行压缩和结果展示。
///
/// 构建设计：页面保持单任务闭环，批量队列后续独立抽取；按钮在处理中禁用，
/// 避免重复触发原生压缩造成文件覆盖或状态错乱。
class CompressView extends GetView<CompressController> {
  const CompressView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片压缩')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePickerCard(controller: controller),
            const SizedBox(height: 16),
            _QualityCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.compress,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compress),
                label: Text(controller.isBusy.value ? '压缩中' : '开始压缩'),
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

  final CompressController controller;

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
                const Text('请选择一张 JPG、PNG 或 WebP 图片进行本地压缩。')
              else ...[
                Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(controller.formatBytes(image.sizeBytes)),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    controller.isBusy.value ? null : controller.pickImage,
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

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('压缩质量', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('当前质量：${controller.quality.value}%'),
              Slider(
                value: controller.quality.value.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '${controller.quality.value}%',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateQuality,
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

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const SizedBox.shrink();
      }
      final savedPercent = (result.savedRatio * 100).toStringAsFixed(1);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('压缩结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('原始大小：${controller.formatBytes(result.source.sizeBytes)}'),
              Text('导出大小：${controller.formatBytes(result.outputSizeBytes)}'),
              Text('节省空间：$savedPercent%'),
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
