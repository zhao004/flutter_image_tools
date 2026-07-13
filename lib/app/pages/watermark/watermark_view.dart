import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../utils/watermark_layout.dart';
import '../../utils/watermark_opacity.dart';
import '../../widgets/image_editor_scaffold.dart';
import 'watermark_controller.dart';

/// 文字水印编辑页：选择图片后在画布中实时预览文字、位置、颜色和透明度。
///
/// 设计意图：水印参数按内容、位置、样式分组放入底部工具栏，预览层只做轻量叠加展示；导出仍
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
          overlayBuilder: (context, previewSize) => _TextWatermarkOverlay(
            controller: controller,
            image: previewImage,
            previewSize: previewSize,
          ),
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
  const _TextWatermarkOverlay({
    required this.controller,
    required this.image,
    required this.previewSize,
  });

  final WatermarkController controller;
  final LocalImageFile image;
  final Size previewSize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.textRevision.value;
      final text = controller.textController.text.trim().isEmpty
          ? 'watermark.config.text'.tr
          : controller.textController.text.trim();
      return IgnorePointer(
        child: CustomPaint(
          key: ValueKey(
            controller.position.value == WatermarkPosition.tile
                ? 'text-watermark-tile-layer'
                : 'text-watermark-preview-layer',
          ),
          painter: TextWatermarkPreviewPainter(
            text: text,
            sourceSize: Size(image.width.toDouble(), image.height.toDouble()),
            previewSize: previewSize,
            position: controller.position.value,
            color: controller.color.value,
            fontSize: controller.fontSize.value,
            opacity: controller.opacity.value,
            spacing: controller.spacing.value,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

/// 文字水印预览绘制器，直接在原图坐标系中复用导出位置和平铺参数后整体缩放。
class TextWatermarkPreviewPainter extends CustomPainter {
  TextWatermarkPreviewPainter({
    required this.text,
    required this.sourceSize,
    required this.previewSize,
    required this.position,
    required this.color,
    required this.fontSize,
    required this.opacity,
    required this.spacing,
  });

  final String text;
  final Size sourceSize;
  final Size previewSize;
  final WatermarkPosition position;
  final Color color;
  final int fontSize;
  final int opacity;
  final int spacing;

  Color get effectiveColor =>
      color.withAlpha(WatermarkOpacity.alphaFromPercent(opacity));

  @override
  void paint(Canvas canvas, Size size) {
    final sourceWidth = math.max(1, sourceSize.width.round());
    final sourceHeight = math.max(1, sourceSize.height.round());
    final scale = WatermarkLayout.previewScale(
      sourceWidth: sourceWidth.toDouble(),
      sourceHeight: sourceHeight.toDouble(),
      previewWidth: size.width,
      previewHeight: size.height,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: effectiveColor,
          fontSize: fontSize.toDouble(),
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: sourceWidth.toDouble());
    final overlayWidth = math.max(1, textPainter.width.ceil());
    final overlayHeight = math.max(1, textPainter.height.ceil());
    final origin = Offset(
      (size.width - sourceWidth * scale) / 2,
      (size.height - sourceHeight * scale) / 2,
    );

    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(scale);
    if (position == WatermarkPosition.tile) {
      _paintTiles(
        canvas: canvas,
        textPainter: textPainter,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        overlayWidth: overlayWidth,
        overlayHeight: overlayHeight,
      );
    } else {
      final offset = WatermarkLayout.positionOffset(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        overlayWidth: overlayWidth,
        overlayHeight: overlayHeight,
        position: position.value,
      );
      textPainter.paint(
        canvas,
        Offset(offset.x.toDouble(), offset.y.toDouble()),
      );
    }
    canvas.restore();
  }

  void _paintTiles({
    required Canvas canvas,
    required TextPainter textPainter,
    required int sourceWidth,
    required int sourceHeight,
    required int overlayWidth,
    required int overlayHeight,
  }) {
    final tileLayout = WatermarkLayout.tileOutputLayout(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      overlayWidth: overlayWidth,
      overlayHeight: overlayHeight,
      spacing: spacing,
    );
    canvas
      ..save()
      ..translate(sourceWidth / 2, sourceHeight / 2)
      ..rotate(WatermarkLayout.tileRotationDegrees * math.pi / 180)
      ..translate(-tileLayout.layerSize / 2, -tileLayout.layerSize / 2);
    for (final offset in tileLayout.offsets) {
      textPainter.paint(
        canvas,
        Offset(offset.x.toDouble(), offset.y.toDouble()),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TextWatermarkPreviewPainter oldDelegate) {
    return text != oldDelegate.text ||
        sourceSize != oldDelegate.sourceSize ||
        previewSize != oldDelegate.previewSize ||
        position != oldDelegate.position ||
        color != oldDelegate.color ||
        fontSize != oldDelegate.fontSize ||
        opacity != oldDelegate.opacity ||
        spacing != oldDelegate.spacing;
  }
}

class _WatermarkBottomToolPanel extends StatefulWidget {
  const _WatermarkBottomToolPanel({required this.controller});

  final WatermarkController controller;

  @override
  State<_WatermarkBottomToolPanel> createState() =>
      _WatermarkBottomToolPanelState();
}

class _WatermarkBottomToolPanelState extends State<_WatermarkBottomToolPanel> {
  String _activeCategoryId = 'content';

  @override
  Widget build(BuildContext context) {
    final categories = [
      ToolCategory(
        id: 'content',
        name: 'watermark.group.content'.tr,
        icon: Icons.text_fields_outlined,
      ),
      ToolCategory(
        id: 'position',
        name: 'watermark.group.position'.tr,
        icon: Icons.open_with_outlined,
      ),
      ToolCategory(
        id: 'style',
        name: 'watermark.group.style'.tr,
        icon: Icons.tune_outlined,
      ),
    ];
    return EditorDynamicToolPanel(
      categories: categories,
      activeCategoryId: _activeCategoryId,
      onCategorySelected: (category) {
        FocusScope.of(context).unfocus();
        setState(() => _activeCategoryId = category.id);
      },
      activePanel: _panelForCategory(_activeCategoryId),
      maxPanelHeight: 128,
      showPanelHeader: false,
    );
  }

  Widget _panelForCategory(String categoryId) {
    return switch (categoryId) {
      'position' => _WatermarkPositionPanel(controller: widget.controller),
      'style' => _WatermarkStylePanel(controller: widget.controller),
      _ => _WatermarkContentPanel(controller: widget.controller),
    };
  }
}

class _WatermarkContentPanel extends StatelessWidget {
  const _WatermarkContentPanel({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: controller.textController,
                  enabled: !controller.isBusy.value,
                  textAlignVertical: TextAlignVertical.center,
                  minLines: 1,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: 'watermark.config.text'.tr,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              if (controller.tasks.isNotEmpty) ...[
                const SizedBox(width: 16),
                _WatermarkProgressIndicator(controller: controller),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _WatermarkColorButton extends StatelessWidget {
  const _WatermarkColorButton({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final colorScheme = Theme.of(context).colorScheme;
      return OutlinedButton.icon(
        key: const ValueKey('watermark-color-picker-button'),
        onPressed: controller.isBusy.value
            ? null
            : () => _showWatermarkColorPicker(context, controller),
        icon: DecoratedBox(
          decoration: BoxDecoration(
            color: controller.color.value,
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: const SizedBox(width: 18, height: 18),
        ),
        label: Text(controller.colorHex),
      );
    });
  }
}

Future<void> _showWatermarkColorPicker(
  BuildContext context,
  WatermarkController controller,
) async {
  final selectedColor = await showColorPickerDialog(
    context,
    controller.color.value.withValues(alpha: 1),
    title: Text('watermark.color.title'.tr),
    pickersEnabled: const <ColorPickerType, bool>{
      ColorPickerType.both: false,
      ColorPickerType.primary: true,
      ColorPickerType.accent: true,
      ColorPickerType.bw: true,
      ColorPickerType.custom: false,
      ColorPickerType.wheel: true,
    },
    enableOpacity: false,
    showColorCode: true,
    wheelDiameter: 190,
    copyPasteBehavior: const ColorPickerCopyPasteBehavior(
      copyButton: true,
      pasteButton: true,
      copyFormat: ColorPickerCopyFormat.numHexRRGGBB,
      parseShortHexCode: true,
    ),
    actionButtons: ColorPickerActionButtons(
      dialogOkButtonLabel: 'common.confirm'.tr,
      dialogCancelButtonLabel: 'common.cancel'.tr,
      dialogOkButtonType: ColorPickerActionButtonType.filled,
    ),
  );

  if (!context.mounted) {
    return;
  }
  controller.setColor(selectedColor.withValues(alpha: 1));
}

class _WatermarkPositionPanel extends StatelessWidget {
  const _WatermarkPositionPanel({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: EditorOptionWrap<WatermarkPosition>(
          values: WatermarkPosition.values,
          selected: controller.position.value,
          labelFor: (value) => value.labelKey.tr,
          enabled: !controller.isBusy.value,
          onSelected: controller.setPosition,
        ),
      );
    });
  }
}

class _WatermarkStylePanel extends StatelessWidget {
  const _WatermarkStylePanel({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _WatermarkColorButton(controller: controller),
            const SizedBox(width: 16),
            _WatermarkSlider(
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
            const SizedBox(width: 16),
            _WatermarkSlider(
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
            if (controller.position.value == WatermarkPosition.tile) ...[
              const SizedBox(width: 16),
              _WatermarkSlider(
                label: 'watermark.config.spacing'.trParams({
                  'spacing': '${controller.spacing.value}',
                }),
                value: controller.spacing.value.toDouble(),
                min: 8,
                max: 160,
                divisions: 38,
                enabled: !controller.isBusy.value,
                onChanged: controller.updateSpacing,
              ),
            ],
            if (controller.tasks.isNotEmpty) ...[
              const SizedBox(width: 16),
              _WatermarkProgressIndicator(controller: controller),
            ],
          ],
        ),
      );
    });
  }
}

class _WatermarkProgressIndicator extends StatelessWidget {
  const _WatermarkProgressIndicator({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
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
    );
  }
}

class _WatermarkSlider extends StatelessWidget {
  const _WatermarkSlider({
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
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
