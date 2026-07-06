import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'rotate_controller.dart';

/// 图片旋转编辑页：选择图片后在画布中实时预览旋转角度。
///
/// 设计意图：角度调节集中在底部工具栏，单图实时预览，右上角保存沿用
/// 控制器导出能力，避免 UI 层重复实现文件处理与异常记录逻辑。
class RotateView extends GetView<RotateController> {
  const RotateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'rotate.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.rotate_90_degrees_ccw_outlined,
        emptyTitle: 'rotate.image.title'.tr,
        emptyMessage: 'rotate.image.empty'.tr,
        pickLabel: 'rotate.action.pickSingle'.tr,
        repickLabel: 'rotate.action.repickSingle'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.rotate,
        imageMeta: image == null
            ? null
            : '${controller.formatBytes(image.sizeBytes)} · ${controller.degrees.value}°',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          transform: Matrix4.rotationZ(
            controller.degrees.value * math.pi / 180,
          ),
        ),
        toolbar: _RotateToolbar(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'rotate.result.title'.tr,
                detail:
                    '${result.degrees}° · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }
}

class _RotateToolbar extends StatelessWidget {
  const _RotateToolbar({required this.controller});

  final RotateController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'rotate.angle.title'.tr,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _AngleChip(
                label: 'rotate.angle.left90'.tr,
                selected: controller.degrees.value == -90,
                enabled: !controller.isBusy.value,
                onTap: () => controller.setDegrees(-90),
              ),
              _AngleChip(
                label: 'rotate.angle.right90'.tr,
                selected: controller.degrees.value == 90,
                enabled: !controller.isBusy.value,
                onTap: () => controller.setDegrees(90),
              ),
              _AngleChip(
                label: 'rotate.angle.oneEighty'.tr,
                selected: controller.degrees.value == 180,
                enabled: !controller.isBusy.value,
                onTap: () => controller.setDegrees(180),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'rotate.angle.custom'.trParams({
            'degrees': controller.degrees.value.toString(),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: controller.degrees.value.clamp(-180, 180).toDouble(),
          min: -180,
          max: 180,
          divisions: 360,
          label: '${controller.degrees.value}°',
          onChanged: controller.isBusy.value
              ? null
              : controller.updateCustomDegrees,
        ),
        if (controller.tasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 6),
          Text(
            'rotate.progress.processed'.trParams({
              'processed': controller.processedCount.value.toString(),
              'total': controller.selectedImages.length.toString(),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _AngleChip extends StatelessWidget {
  const _AngleChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: enabled ? (_) => onTap() : null,
      ),
    );
  }
}
