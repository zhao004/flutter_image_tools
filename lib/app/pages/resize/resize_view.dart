import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'resize_controller.dart';

/// 图片尺寸编辑页：选择图片后在画布中实时预览目标尺寸比例。
///
/// 设计意图：尺寸输入、保持比例和百分比缩放集中在底部工具栏；预览层只
/// 展示目标比例边框，实际像素重采样继续交给控制器和原生通道处理。
class ResizeView extends GetView<ResizeController> {
  const ResizeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'resize.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.aspect_ratio_outlined,
        emptyTitle: 'resize.image.title'.tr,
        emptyMessage: 'resize.image.empty'.tr,
        pickLabel: 'resize.action.pickSingle'.tr,
        repickLabel: 'resize.action.repickSingle'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.resize,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${_targetSizeText()}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          child: _ResizeOverlay(aspectRatio: _targetAspectRatio(previewImage)),
        ),
        toolbar: _ResizeToolbar(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'resize.result.title'.tr,
                detail:
                    '${result.width} × ${result.height} px · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }

  String _targetSizeText() {
    final width = controller.widthController.text.trim();
    final height = controller.heightController.text.trim();
    if (width.isEmpty || height.isEmpty) {
      return 'resize.size.percent'.trParams({
        'percent': controller.percent.value.round().toString(),
      });
    }
    return '$width × $height px';
  }

  double _targetAspectRatio(dynamic image) {
    final width = double.tryParse(controller.widthController.text.trim());
    final height = double.tryParse(controller.heightController.text.trim());
    if (width != null && height != null && width > 0 && height > 0) {
      return (width / height).clamp(0.1, 10);
    }
    if (image.hasValidDimensions && image.height > 0) {
      return image.width / image.height;
    }
    return 1;
  }
}

class _ResizeOverlay extends StatelessWidget {
  const _ResizeOverlay({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stageWidth = constraints.maxWidth;
          final stageHeight = constraints.maxHeight;
          var frameWidth = stageWidth * 0.82;
          var frameHeight = frameWidth / aspectRatio;
          if (frameHeight > stageHeight * 0.82) {
            frameHeight = stageHeight * 0.82;
            frameWidth = frameHeight * aspectRatio;
          }
          return Center(
            child: Container(
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                color: Colors.black.withValues(alpha: 0.08),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.aspect_ratio,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResizeToolbar extends StatelessWidget {
  const _ResizeToolbar({required this.controller});

  final ResizeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'resize.size.title'.tr,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('resize.size.keepAspectRatio'.tr),
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
                decoration: InputDecoration(
                  labelText: 'resize.size.width'.tr,
                  suffixText: 'px',
                  border: const OutlineInputBorder(),
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
                decoration: InputDecoration(
                  labelText: 'resize.size.height'.tr,
                  suffixText: 'px',
                  border: const OutlineInputBorder(),
                ),
                onChanged: controller.updateHeight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'resize.size.percent'.trParams({
            'percent': controller.percent.value.round().toString(),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: controller.percent.value.clamp(10, 300),
          min: 10,
          max: 300,
          divisions: 58,
          label: '${controller.percent.value.round()}%',
          onChanged: controller.isBusy.value ? null : controller.updatePercent,
        ),
        if (controller.tasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: controller.progress),
          const SizedBox(height: 6),
          Text(
            'resize.progress.processed'.trParams({
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
