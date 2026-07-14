import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../models/picked_color_sample.dart';
import '../../widgets/tool_task_layout.dart';
import 'color_picker_controller.dart';

/// 颜色提取页，支持在图片显示区域点击或拖动指针连续取色。
class ColorPickerView extends GetView<ColorPickerController> {
  const ColorPickerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final sample = controller.sample.value;
      return AdaptiveTaskScaffold(
        title: 'colorPicker.title'.tr,
        actions: [
          if (image != null)
            IconButton(
              tooltip: 'colorPicker.action.repickImage'.tr,
              onPressed: controller.isBusy.value ? null : controller.pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
        ],
        primary: ToolTaskSection(
          title: 'colorPicker.picker.title'.tr,
          description: image == null
              ? 'colorPicker.image.empty'.tr
              : '${image.name} · ${controller.formatDimensions(image)}',
          child: image == null
              ? OutlinedButton.icon(
                  onPressed: controller.isBusy.value
                      ? null
                      : controller.pickImage,
                  icon: controller.isBusy.value
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('colorPicker.action.pickImage'.tr),
                )
              : _ColorImagePicker(
                  image: image,
                  sample: sample,
                  normalizedPosition: controller.normalizedPosition.value,
                  onPick: controller.pickColor,
                  onDrag: controller.previewColor,
                  onDragEnd: controller.commitColorSelection,
                ),
        ),
        secondary: ToolTaskSection(
          title: 'colorPicker.result.title'.tr,
          description: sample == null
              ? 'colorPicker.result.empty'.tr
              : 'colorPicker.result.coordinate'.trParams({
                  'x': '${sample.x}',
                  'y': '${sample.y}',
                }),
          child: sample == null
              ? const SizedBox.shrink()
              : _ColorResult(controller: controller, sample: sample),
        ),
      );
    });
  }
}

class _ColorImagePicker extends StatelessWidget {
  const _ColorImagePicker({
    required this.image,
    required this.sample,
    required this.normalizedPosition,
    required this.onPick,
    required this.onDrag,
    required this.onDragEnd,
  });

  final LocalImageFile image;
  final PickedColorSample? sample;
  final Offset? normalizedPosition;
  final Future<void> Function({
    required double localX,
    required double localY,
    required double displayWidth,
    required double displayHeight,
  })
  onPick;
  final void Function({
    required double localX,
    required double localY,
    required double displayWidth,
    required double displayHeight,
  })
  onDrag;
  final Future<void> Function() onDragEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final sourceSize = image.hasValidDimensions
            ? Size(image.width.toDouble(), image.height.toDouble())
            : const Size.square(1);
        final naturalHeight = viewportWidth / sourceSize.aspectRatio;
        final viewportHeight = naturalHeight.clamp(240.0, 560.0);
        final viewportSize = Size(viewportWidth, viewportHeight);
        final fitted = applyBoxFit(BoxFit.contain, sourceSize, viewportSize);
        final imageRect = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & viewportSize,
        );
        final position = normalizedPosition;
        final selectedSample = sample;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.fromSize(
            key: const ValueKey('color-picker-viewport'),
            size: viewportSize,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fromRect(
                    rect: imageRect,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        onPick(
                          localX: details.localPosition.dx,
                          localY: details.localPosition.dy,
                          displayWidth: imageRect.width,
                          displayHeight: imageRect.height,
                        );
                      },
                      onPanStart: (details) {
                        onDrag(
                          localX: details.localPosition.dx,
                          localY: details.localPosition.dy,
                          displayWidth: imageRect.width,
                          displayHeight: imageRect.height,
                        );
                      },
                      onPanUpdate: (details) {
                        onDrag(
                          localX: details.localPosition.dx,
                          localY: details.localPosition.dy,
                          displayWidth: imageRect.width,
                          displayHeight: imageRect.height,
                        );
                      },
                      onPanEnd: (_) async {
                        await onDragEnd();
                      },
                      child: Image.file(
                        File(image.path),
                        fit: BoxFit.fill,
                        errorBuilder: (_, _, _) => Center(
                          child: Text('colorPicker.picker.previewFailed'.tr),
                        ),
                      ),
                    ),
                  ),
                  if (position != null && selectedSample != null)
                    Positioned(
                      left: imageRect.left + position.dx * imageRect.width - 16,
                      top: imageRect.top + position.dy * imageRect.height - 16,
                      child: _ColorPointer(sample: selectedSample),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColorPointer extends StatelessWidget {
  const _ColorPointer({required this.sample});

  final PickedColorSample sample;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'colorPicker.pointer.label'.trParams({
        'x': '${sample.x}',
        'y': '${sample.y}',
      }),
      child: IgnorePointer(
        child: SizedBox.square(
          key: const ValueKey('color-picker-pointer'),
          dimension: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sample.color,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 3),
                  ],
                ),
              ),
              Container(width: 32, height: 2, color: Colors.black87),
              Container(width: 2, height: 32, color: Colors.black87),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorResult extends StatelessWidget {
  const _ColorResult({required this.controller, required this.sample});

  final ColorPickerController controller;
  final PickedColorSample sample;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 72,
          decoration: BoxDecoration(
            color: sample.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CopyRow(label: 'HEX', value: sample.hexText, controller: controller),
        _CopyRow(label: 'RGB', value: sample.rgbText, controller: controller),
        _CopyRow(label: 'HSV', value: sample.hsvText, controller: controller),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.controller,
  });

  final String label;
  final String value;
  final ColorPickerController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: IconButton(
        tooltip: 'colorPicker.action.copyLabel'.trParams({'label': label}),
        onPressed: () => controller.copyValue(value),
        icon: const Icon(Icons.copy_outlined),
      ),
    );
  }
}
