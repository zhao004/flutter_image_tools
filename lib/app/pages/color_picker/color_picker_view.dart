import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'color_picker_controller.dart';

/// 颜色提取页，支持从本地图片点击取色并复制 RGB、HEX、HSV 值。
///
/// 构建设计：使用原图等比预览和点击坐标映射像素，避免额外图片处理依赖；
/// 当前阶段不做缩放拖拽，优先保证点击取色链路稳定可验证。
class ColorPickerView extends GetView<ColorPickerController> {
  const ColorPickerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('colorPicker.title'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageInfoCard(controller: controller),
            const SizedBox(height: 16),
            _PickerCard(controller: controller),
            const SizedBox(height: 16),
            _ResultCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _ImageInfoCard extends StatelessWidget {
  const _ImageInfoCard({required this.controller});

  final ColorPickerController controller;

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
              Text(
                'colorPicker.image.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                Text('colorPicker.image.empty'.tr)
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
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'colorPicker.action.loading'.tr
                      : image == null
                      ? 'colorPicker.action.pickImage'.tr
                      : 'colorPicker.action.repickImage'.tr,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({required this.controller});

  final ColorPickerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'colorPicker.picker.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (image == null)
                Text('colorPicker.picker.empty'.tr)
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final imageRatio = image.hasValidDimensions
                        ? image.width / image.height
                        : 1.0;
                    final width = constraints.maxWidth;
                    final height = (width / imageRatio).clamp(160.0, 420.0);
                    return GestureDetector(
                      onTapDown: (details) => controller.pickColor(
                        localX: details.localPosition.dx,
                        localY: details.localPosition.dy,
                        displayWidth: width,
                        displayHeight: height,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Image.file(
                            File(image.path),
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) {
                              return ColoredBox(
                                color: Colors.black12,
                                child: Center(
                                  child: Text(
                                    'colorPicker.picker.previewFailed'.tr,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller});

  final ColorPickerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sample = controller.sample.value;
      if (sample == null) {
        return const SizedBox.shrink();
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'colorPicker.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: sample.color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'colorPicker.result.coordinate'.trParams({
                        'x': '${sample.x}',
                        'y': '${sample.y}',
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CopyRow(
                label: 'HEX',
                value: sample.hexText,
                onCopy: controller.copyValue,
              ),
              _CopyRow(
                label: 'RGB',
                value: sample.rgbText,
                onCopy: controller.copyValue,
              ),
              _CopyRow(
                label: 'HSV',
                value: sample.hsvText,
                onCopy: controller.copyValue,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: IconButton(
        tooltip: 'colorPicker.action.copyLabel'.trParams({'label': label}),
        onPressed: () => onCopy(value),
        icon: const Icon(Icons.copy),
      ),
    );
  }
}
