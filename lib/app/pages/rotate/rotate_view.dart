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
        bottomToolbar: _RotateBottomToolPanel(controller: controller),
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

class _RotateBottomToolPanel extends StatelessWidget {
  const _RotateBottomToolPanel({required this.controller});

  final RotateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => EditorDynamicToolPanel(
        categories: [
          ToolCategory(
            id: 'angle',
            name: 'rotate.angle.title'.tr,
            icon: Icons.rotate_90_degrees_ccw_outlined,
            subItems: [
              ToolSubItem(
                id: '-90',
                name: 'rotate.angle.left90'.tr,
                icon: Icons.rotate_left,
              ),
              ToolSubItem(
                id: '90',
                name: 'rotate.angle.right90'.tr,
                icon: Icons.rotate_right,
              ),
              ToolSubItem(
                id: '180',
                name: 'rotate.angle.oneEighty'.tr,
                icon: Icons.refresh,
              ),
            ],
          ),
        ],
        activeCategoryId: 'angle',
        activeSubItemId: _presetAngleId(controller.degrees.value),
        activePanelTitle: 'rotate.angle.title'.tr,
        activePanel: _RotateCustomAnglePanel(controller: controller),
        onCategorySelected: (_) {},
        onSubItemSelected: (item) {
          final degrees = int.tryParse(item.id);
          if (degrees != null) {
            controller.setDegrees(degrees);
          }
        },
      ),
    );
  }

  String? _presetAngleId(int degrees) {
    return switch (degrees) {
      -90 => '-90',
      90 => '90',
      180 => '180',
      _ => null,
    };
  }
}

class _RotateCustomAnglePanel extends StatelessWidget {
  const _RotateCustomAnglePanel({required this.controller});

  final RotateController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      ),
    );
  }
}
