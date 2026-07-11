import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        child: _DiagonalTextWatermarkTile(
          key: const ValueKey('text-watermark-tile-layer'),
          text: text,
          watermark: watermark,
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

class _DiagonalTextWatermarkTile extends StatelessWidget {
  const _DiagonalTextWatermarkTile({
    super.key,
    required this.text,
    required this.watermark,
  });

  static const double _tileRotationRadians = -math.pi / 6;
  static const double _horizontalGap = 72;
  static const double _verticalGap = 52;

  final String text;
  final Widget watermark;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safeWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final safeHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final estimatedTextWidth = math.max(
            96.0,
            text.characters.length * 20,
          );
          final tileWidth = estimatedTextWidth + _horizontalGap;
          final tileHeight = 64.0 + _verticalGap;
          final expandedWidth = safeWidth + safeHeight;
          final expandedHeight = safeWidth + safeHeight;
          final columnCount = (expandedWidth / tileWidth).ceil() + 4;
          final rowCount = (expandedHeight / tileHeight).ceil() + 4;
          final originLeft = (expandedWidth - columnCount * tileWidth) / 2;
          final originTop = (expandedHeight - rowCount * tileHeight) / 2;

          return Transform.rotate(
            angle: _tileRotationRadians,
            child: OverflowBox(
              minWidth: expandedWidth,
              maxWidth: expandedWidth,
              minHeight: expandedHeight,
              maxHeight: expandedHeight,
              child: SizedBox(
                width: expandedWidth,
                height: expandedHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
                      for (
                        var columnIndex = 0;
                        columnIndex < columnCount;
                        columnIndex++
                      )
                        Positioned(
                          left:
                              originLeft +
                              columnIndex * tileWidth +
                              (rowIndex.isOdd ? tileWidth / 2 : 0),
                          top: originTop + rowIndex * tileHeight,
                          width: tileWidth,
                          height: tileHeight,
                          child: Center(child: watermark),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 240,
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
          if (controller.tasks.isNotEmpty) ...[
            const SizedBox(width: 16),
            _WatermarkProgressIndicator(controller: controller),
          ],
        ],
      ),
    );
  }
}

class _WatermarkPositionPanel extends StatelessWidget {
  const _WatermarkPositionPanel({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
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
  }
}

class _WatermarkStylePanel extends StatelessWidget {
  const _WatermarkStylePanel({required this.controller});

  final WatermarkController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          EditorOptionWrap<WatermarkColor>(
            values: WatermarkColor.values,
            selected: controller.color.value,
            labelFor: (value) => value.labelKey.tr,
            enabled: !controller.isBusy.value,
            onSelected: controller.setColor,
          ),
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
          if (controller.tasks.isNotEmpty) ...[
            const SizedBox(width: 16),
            _WatermarkProgressIndicator(controller: controller),
          ],
        ],
      ),
    );
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
