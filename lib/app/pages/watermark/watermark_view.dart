import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'watermark_controller.dart';

/// 文字水印编辑页：选择图片后在画布中实时预览文字、位置、颜色和透明度。
///
/// 设计意图：水印参数集中在底部工具栏，预览层只做轻量叠加展示；导出仍
/// 使用控制器的原生合成逻辑，保证文件处理、历史记录和异常提示一致。
class WatermarkView extends GetView<WatermarkController> {
  const WatermarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'watermark.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.text_fields_outlined,
        emptyTitle: 'watermark.image.title'.tr,
        emptyMessage: 'watermark.image.empty'.tr,
        pickLabel: 'watermark.action.pickSingle'.tr,
        repickLabel: 'watermark.action.repickSingle'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.addWatermark,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${controller.position.value.labelKey.tr}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          child: _TextWatermarkOverlay(controller: controller),
        ),
        showPreviewInfo: false,
        expandPreviewToAvailableHeight: true,
        bottomToolbar: _WatermarkBottomToolPanel(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'watermark.result.title'.tr,
                detail:
                    '${controller.positionLabel(result.position)} · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }
}

class _TextWatermarkOverlay extends StatelessWidget {
  const _TextWatermarkOverlay({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.textController.text.trim().isEmpty
        ? 'watermark.config.text'.tr
        : controller.textController.text.trim();
    final watermark = Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _watermarkColor(
          controller.color.value,
        ).withValues(alpha: controller.opacity.value / 100),
        fontSize: controller.fontSize.value.toDouble(),
        fontWeight: FontWeight.w700,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
    if (controller.position.value == WatermarkPosition.tile) {
      return IgnorePointer(
        child: Wrap(
          spacing: 40,
          runSpacing: 28,
          children: List.generate(24, (_) => watermark),
        ),
      );
    }
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Align(
          alignment: _alignmentFor(controller.position.value),
          child: watermark,
        ),
      ),
    );
  }

  Alignment _alignmentFor(WatermarkPosition position) {
    switch (position) {
      case WatermarkPosition.topLeft:
        return Alignment.topLeft;
      case WatermarkPosition.topRight:
        return Alignment.topRight;
      case WatermarkPosition.bottomLeft:
        return Alignment.bottomLeft;
      case WatermarkPosition.bottomRight:
        return Alignment.bottomRight;
      case WatermarkPosition.center:
      case WatermarkPosition.tile:
        return Alignment.center;
    }
  }

  Color _watermarkColor(WatermarkColor color) {
    switch (color) {
      case WatermarkColor.white:
        return Colors.white;
      case WatermarkColor.black:
        return Colors.black;
      case WatermarkColor.red:
        return const Color(0xFFE53935);
      case WatermarkColor.yellow:
        return const Color(0xFFFDD835);
    }
  }
}

class _WatermarkBottomToolPanel extends StatelessWidget {
  const _WatermarkBottomToolPanel({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return EditorDynamicToolPanel(
      categories: [
        ToolCategory(
          id: 'watermark',
          name: 'watermark.config.text'.tr,
          icon: Icons.text_fields_outlined,
        ),
      ],
      activeCategoryId: 'watermark',
      onCategorySelected: (_) {},
      activePanel: _WatermarkPropertyPanel(controller: controller),
      maxPanelHeight: 96,
      showPanelHeader: false,
    );
  }
}

class _WatermarkPropertyPanel extends StatelessWidget {
  const _WatermarkPropertyPanel({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: TextField(
              controller: controller.textController,
              enabled: !controller.isBusy.value,
              minLines: 1,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: 'watermark.config.text'.tr,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => controller.fontSize.refresh(),
            ),
          ),
          const SizedBox(width: 10),
          EditorOptionWrap<WatermarkPosition>(
            values: WatermarkPosition.values,
            selected: controller.position.value,
            labelFor: (value) => value.labelKey.tr,
            enabled: !controller.isBusy.value,
            onSelected: controller.setPosition,
          ),
          const SizedBox(width: 10),
          EditorOptionWrap<WatermarkColor>(
            values: WatermarkColor.values,
            selected: controller.color.value,
            labelFor: (value) => value.labelKey.tr,
            enabled: !controller.isBusy.value,
            onSelected: controller.setColor,
          ),
          const SizedBox(width: 10),
          _CompactSlider(
            label: 'watermark.config.fontSize'.trParams({
              'size': '${controller.fontSize.value}',
            }),
            value: controller.fontSize.value.toDouble(),
            min: 12,
            max: 160,
            divisions: 37,
            enabled: !controller.isBusy.value,
            onChanged: controller.updateFontSize,
          ),
          const SizedBox(width: 10),
          _CompactSlider(
            label: 'watermark.config.opacity'.trParams({
              'opacity': '${controller.opacity.value}',
            }),
            value: controller.opacity.value.toDouble(),
            min: 10,
            max: 100,
            divisions: 18,
            enabled: !controller.isBusy.value,
            onChanged: controller.updateOpacity,
          ),
          if (controller.tasks.isNotEmpty) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 160,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: controller.progress),
                  const SizedBox(height: 4),
                  Text(
                    'watermark.progress.processed'.trParams({
                      'processed': '${controller.processedCount.value}',
                      'total': '${controller.selectedImages.length}',
                    }),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  const _CompactSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
