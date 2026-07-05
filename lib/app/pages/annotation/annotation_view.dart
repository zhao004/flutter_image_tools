import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'annotation_controller.dart';

/// 图片标注页，支持基础画笔、箭头、形状、文本、高亮和马赛克导出。
///
/// 构建设计：当前版本提供预设标注区域和样式，先形成离线导出闭环；后续可在
/// 此页面扩展自由拖拽、橡皮擦和多图层编辑。
class AnnotationView extends GetView<AnnotationController> {
  const AnnotationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片标注')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageCard(controller: controller),
            const SizedBox(height: 16),
            _AnnotationCard(controller: controller),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isBusy.value ? null : controller.annotate,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(controller.isBusy.value ? '标注中' : '导出标注图片'),
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

  final AnnotationController controller;

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
                const Text('请选择一张本地图片，随后选择标注类型并导出副本。')
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

class _AnnotationCard extends StatelessWidget {
  const _AnnotationCard({required this.controller});

  final AnnotationController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('标注样式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AnnotationMode.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.mode.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setMode(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller.textController,
                enabled:
                    !controller.isBusy.value &&
                    controller.mode.value == AnnotationMode.text,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '文本内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text('颜色', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AnnotationColor.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.color.value == item,
                        onSelected: controller.isBusy.value
                            ? null
                            : (_) => controller.setColor(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text('粗细：${controller.strokeWidth.value}px'),
              Slider(
                value: controller.strokeWidth.value.toDouble(),
                min: 2,
                max: 48,
                divisions: 23,
                label: '${controller.strokeWidth.value}px',
                onChanged: controller.isBusy.value
                    ? null
                    : controller.updateStrokeWidth,
              ),
              const Text('当前版本使用预设区域绘制标注，导出时不会覆盖原图。'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller});

  final AnnotationController controller;

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
              Text('标注结果', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('标注模式：${result.mode}'),
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
