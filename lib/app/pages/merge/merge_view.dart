import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../widgets/image_editor_scaffold.dart';
import 'merge_controller.dart';

/// 图片拼接编辑页，选图后在主预览区实时展示拼接布局。
///
/// 构建设计：未选图时保持统一空状态；选图后复用编辑器骨架，右上角保存
/// 执行导出，底部工具栏按布局、样式和排序分组展示，避免所有参数堆叠在
/// 同一个页面里挤压预览空间。
class MergeView extends GetView<MergeController> {
  const MergeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final images = controller.selectedImages;
      final selectedImage = images.isEmpty ? null : images.first;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'merge.title'.tr,
        selectedImage: selectedImage,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.view_column_outlined,
        emptyTitle: 'merge.image.title'.tr,
        emptyMessage: 'merge.image.empty'.tr,
        pickLabel: 'merge.action.pickBatch'.tr,
        repickLabel: 'merge.action.repickBatch'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImages,
        onExport: controller.merge,
        imageMeta: images.isEmpty
            ? null
            : '${'merge.image.selectedCount'.trParams({'count': images.length.toString()})} · ${controller.formatBytes(controller.totalSizeBytes)}',
        showPreviewInfo: false,
        lockPreviewScroll: true,
        expandPreviewToAvailableHeight: true,
        previewBuilder: (context, _) => _MergePreview(controller: controller),
        bottomToolbar: _MergeBottomToolPanel(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'merge.result.title'.tr,
                detail:
                    '${result.width} × ${result.height} px · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }
}

class _MergePreview extends StatelessWidget {
  const _MergePreview({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final images = controller.selectedImages.toList(growable: false);
      final backgroundColor = _parseColor(
        controller.backgroundColor.value.value,
      );
      final spacing = controller.spacing.value.toDouble();
      final borderWidth = controller.borderWidth.value.toDouble();
      final borderColor = _parseColor(controller.borderColor.value.value);
      final cornerRadius = controller.cornerRadius.value.toDouble();
      final mode = controller.mode.value;

      return LayoutBuilder(
        builder: (context, constraints) {
          final previewWidth = constraints.maxWidth.isFinite
              ? math.max(1.0, math.min(constraints.maxWidth, 900)).toDouble()
              : 900.0;
          final previewHeight = constraints.maxHeight.isFinite
              ? math.max(1.0, math.min(constraints.maxHeight, 560)).toDouble()
              : 560.0;
          final shortestSide = math.min(previewWidth, previewHeight);
          final previewPadding = math
              .min(math.max(spacing, 6), shortestSide * 0.2)
              .toDouble();
          return SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: backgroundColor),
              child: Padding(
                padding: EdgeInsets.all(previewPadding),
                child: _MergePreviewLayout(
                  images: images,
                  mode: mode,
                  spacing: spacing,
                  borderWidth: borderWidth,
                  borderColor: borderColor,
                  cornerRadius: cornerRadius,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _MergePreviewLayout extends StatelessWidget {
  const _MergePreviewLayout({
    required this.images,
    required this.mode,
    required this.spacing,
    required this.borderWidth,
    required this.borderColor,
    required this.cornerRadius,
  });

  final List<LocalImageFile> images;
  final MergeMode mode;
  final double spacing;
  final double borderWidth;
  final Color borderColor;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? math.max(1.0, constraints.maxWidth)
            : 900.0;
        final viewportHeight = constraints.maxHeight.isFinite
            ? math.max(1.0, constraints.maxHeight)
            : 560.0;
        return switch (mode) {
          MergeMode.horizontal => _buildHorizontal(
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
          ),
          MergeMode.vertical => _buildVertical(
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
          ),
        };
      },
    );
  }

  Widget _buildHorizontal({
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final tileSpecs = _horizontalTileSpecs();
    final contentWidth =
        tileSpecs.fold<double>(0, (sum, tile) => sum + tile.width) +
        spacing * (tileSpecs.length - 1);
    final contentHeight = tileSpecs.fold<double>(
      0,
      (height, tile) => math.max(height, tile.height),
    );
    final previewScale = _fitScale(
      visibleContentExtent: _horizontalVisibleWidth(tileSpecs),
      viewportExtent: viewportWidth,
      visibleTileCount: _visibleTileCount,
    );
    final tiles = tileSpecs
        .map(
          (tile) => SizedBox(
            key: ValueKey('merge-preview-tile-${tile.image.path}'),
            width: tile.width * previewScale,
            height: tile.height * previewScale,
            child: _tile(tile.image),
          ),
        )
        .toList(growable: false);
    final scaledContentWidth = contentWidth * previewScale;
    final scaledContentHeight = contentHeight * previewScale;
    return _ScrollablePreview(
      key: const ValueKey('merge-preview-horizontal-scroll'),
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      contentWidth: scaledContentWidth,
      contentHeight: scaledContentHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: _withSpacing(tiles, isHorizontal: true, scale: previewScale),
      ),
    );
  }

  Widget _buildVertical({
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final tileSpecs = _verticalTileSpecs();
    final contentWidth = tileSpecs.fold<double>(
      0,
      (width, tile) => math.max(width, tile.width),
    );
    final contentHeight =
        tileSpecs.fold<double>(0, (sum, tile) => sum + tile.height) +
        spacing * (tileSpecs.length - 1);
    final previewScale = _fitScale(
      visibleContentExtent: _verticalVisibleHeight(tileSpecs),
      viewportExtent: viewportHeight,
      visibleTileCount: _visibleTileCount,
    );
    final tiles = tileSpecs
        .map(
          (tile) => SizedBox(
            key: ValueKey('merge-preview-tile-${tile.image.path}'),
            width: tile.width * previewScale,
            height: tile.height * previewScale,
            child: _tile(tile.image),
          ),
        )
        .toList(growable: false);
    final scaledContentWidth = contentWidth * previewScale;
    final scaledContentHeight = contentHeight * previewScale;
    return _ScrollablePreview(
      key: const ValueKey('merge-preview-vertical-scroll'),
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      contentWidth: scaledContentWidth,
      contentHeight: scaledContentHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: _withSpacing(tiles, isHorizontal: false, scale: previewScale),
      ),
    );
  }

  Widget _tile(LocalImageFile image) {
    return _PreviewImageTile(
      image: image,
      borderWidth: borderWidth,
      borderColor: borderColor,
      cornerRadius: cornerRadius,
    );
  }

  double _aspectRatio(LocalImageFile image) {
    if (!image.hasValidDimensions || image.height <= 0) {
      return 1;
    }
    return (image.width / image.height).clamp(0.05, 20);
  }

  List<_PreviewTileSpec> _horizontalTileSpecs() {
    final targetHeight = images
        .map(_sourceHeight)
        .fold<double>(1, (height, value) => math.max(height, value));
    return images
        .map(
          (image) => _PreviewTileSpec(
            image: image,
            width: targetHeight * _aspectRatio(image),
            height: targetHeight,
          ),
        )
        .toList(growable: false);
  }

  List<_PreviewTileSpec> _verticalTileSpecs() {
    final targetWidth = images
        .map(_sourceWidth)
        .fold<double>(1, (width, value) => math.max(width, value));
    return images
        .map(
          (image) => _PreviewTileSpec(
            image: image,
            width: targetWidth,
            height: targetWidth / _aspectRatio(image),
          ),
        )
        .toList(growable: false);
  }

  double _sourceWidth(LocalImageFile image) {
    return image.hasValidDimensions && image.width > 0
        ? image.width.toDouble()
        : 1;
  }

  double _sourceHeight(LocalImageFile image) {
    return image.hasValidDimensions && image.height > 0
        ? image.height.toDouble()
        : 1;
  }

  double _fitScale({
    required double visibleContentExtent,
    required double viewportExtent,
    required int visibleTileCount,
  }) {
    if (visibleTileCount <= 0 || visibleContentExtent <= 0) {
      return 1;
    }
    final fitScale = viewportExtent / visibleContentExtent;
    return math.min(1.0, fitScale);
  }

  int get _visibleTileCount {
    if (images.length > 3) {
      return 3;
    }
    if (images.length > 2) {
      return 2;
    }
    return images.length;
  }

  double _horizontalVisibleWidth(List<_PreviewTileSpec> tileSpecs) {
    final visibleTiles = tileSpecs
        .take(_visibleTileCount)
        .toList(growable: false);
    return visibleTiles.fold<double>(0, (sum, tile) => sum + tile.width) +
        spacing * math.max(0, visibleTiles.length - 1);
  }

  double _verticalVisibleHeight(List<_PreviewTileSpec> tileSpecs) {
    final visibleTiles = tileSpecs
        .take(_visibleTileCount)
        .toList(growable: false);
    return visibleTiles.fold<double>(0, (sum, tile) => sum + tile.height) +
        spacing * math.max(0, visibleTiles.length - 1);
  }

  List<Widget> _withSpacing(
    List<Widget> children, {
    required bool isHorizontal,
    required double scale,
  }) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(
          SizedBox(
            width: isHorizontal ? spacing * scale : 0,
            height: isHorizontal ? 0 : spacing * scale,
          ),
        );
      }
      spaced.add(children[index]);
    }
    return spaced;
  }
}

class _ScrollablePreview extends StatelessWidget {
  const _ScrollablePreview({
    super.key,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentWidth,
    required this.contentHeight,
    required this.child,
  });

  final double viewportWidth;
  final double viewportHeight;
  final double contentWidth;
  final double contentHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canvasWidth = math.max(viewportWidth, contentWidth);
    final canvasHeight = math.max(viewportHeight, contentHeight);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _PreviewTileSpec {
  const _PreviewTileSpec({
    required this.image,
    required this.width,
    required this.height,
  });

  final LocalImageFile image;
  final double width;
  final double height;
}

class _PreviewImageTile extends StatelessWidget {
  const _PreviewImageTile({
    required this.image,
    required this.borderWidth,
    required this.borderColor,
    required this.cornerRadius,
  });

  final LocalImageFile image;
  final double borderWidth;
  final Color borderColor;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final file = File(image.path);
    final radius = BorderRadius.circular(cornerRadius.clamp(0, 48));
    final child = file.existsSync()
        ? Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return EditorImageLoadError(imageName: image.name);
            },
          )
        : EditorImageLoadError(imageName: image.name);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: radius,
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

class _MergeBottomToolPanel extends StatelessWidget {
  const _MergeBottomToolPanel({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedTab = controller.toolbarTab.value;
      return EditorDynamicToolPanel(
        categories: MergeToolbarTab.values
            .map(
              (tab) => ToolCategory(
                id: tab.name,
                name: tab.labelKey.tr,
                icon: _toolbarTabIcon(tab),
              ),
            )
            .toList(growable: false),
        activeCategoryId: selectedTab.name,
        onCategorySelected: (category) {
          final tab = MergeToolbarTab.values.firstWhereOrNull(
            (value) => value.name == category.id,
          );
          if (tab != null && !controller.isBusy.value) {
            controller.setToolbarTab(tab);
          }
        },
        activePanel: _MergeToolPanel(
          controller: controller,
          selectedTab: selectedTab,
        ),
        maxPanelHeight: switch (selectedTab) {
          MergeToolbarTab.layout => 156,
          MergeToolbarTab.border => 236,
          MergeToolbarTab.background => 112,
          MergeToolbarTab.order => 220,
        },
        showPanelHeader: false,
      );
    });
  }
}

class _MergeToolPanel extends StatelessWidget {
  const _MergeToolPanel({required this.controller, required this.selectedTab});

  final MergeController controller;
  final MergeToolbarTab selectedTab;

  @override
  Widget build(BuildContext context) {
    return switch (selectedTab) {
      MergeToolbarTab.layout => _LayoutToolPanel(controller: controller),
      MergeToolbarTab.border => _BorderToolPanel(controller: controller),
      MergeToolbarTab.background => _BackgroundToolPanel(
        controller: controller,
      ),
      MergeToolbarTab.order => _OrderToolPanel(controller: controller),
    };
  }
}

class _LayoutToolPanel extends StatelessWidget {
  const _LayoutToolPanel({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<MergeMode>(
              segments: MergeMode.values
                  .map(
                    (mode) => ButtonSegment<MergeMode>(
                      value: mode,
                      icon: Icon(
                        mode == MergeMode.horizontal
                            ? Icons.view_column_outlined
                            : Icons.view_stream_outlined,
                      ),
                      label: Text(mode.labelKey.tr),
                    ),
                  )
                  .toList(growable: false),
              selected: <MergeMode>{controller.mode.value},
              showSelectedIcon: false,
              onSelectionChanged: controller.isBusy.value
                  ? null
                  : (selection) => controller.setMode(selection.first),
            ),
          ),
          const SizedBox(height: 8),
          _LabeledSlider(
            icon: Icons.space_bar,
            label: 'merge.layout.spacing'.trParams({
              'value': controller.spacing.value.toString(),
            }),
            value: controller.spacing.value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: controller.isBusy.value
                ? null
                : controller.updateSpacing,
          ),
        ],
      ),
    );
  }
}

class _BorderToolPanel extends StatelessWidget {
  const _BorderToolPanel({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledSlider(
            icon: Icons.rounded_corner,
            label: 'merge.layout.cornerRadius'.trParams({
              'value': controller.cornerRadius.value.toString(),
            }),
            value: controller.cornerRadius.value.toDouble(),
            min: 0,
            max: 200,
            divisions: 20,
            onChanged: controller.isBusy.value
                ? null
                : controller.updateCornerRadius,
          ),
          const SizedBox(height: 8),
          _LabeledSlider(
            icon: Icons.border_outer_outlined,
            label: 'merge.layout.borderWidth'.trParams({
              'value': controller.borderWidth.value.toString(),
            }),
            value: controller.borderWidth.value.toDouble(),
            min: 0,
            max: 50,
            divisions: 10,
            onChanged: controller.isBusy.value
                ? null
                : controller.updateBorderWidth,
          ),
          const SizedBox(height: 8),
          _ColorChoiceSection<MergeBorderColor>(
            title: 'merge.layout.borderColor'.tr,
            values: MergeBorderColor.values,
            selected: controller.borderColor.value,
            enabled: !controller.isBusy.value,
            labelFor: (value) => value.labelKey.tr,
            colorFor: (value) => _parseColor(value.value),
            onSelected: controller.setBorderColor,
          ),
        ],
      ),
    );
  }
}

class _BackgroundToolPanel extends StatelessWidget {
  const _BackgroundToolPanel({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _ColorChoiceSection<MergeBackgroundColor>(
        title: 'merge.layout.backgroundColor'.tr,
        values: MergeBackgroundColor.values,
        selected: controller.backgroundColor.value,
        enabled: !controller.isBusy.value,
        labelFor: (value) => value.labelKey.tr,
        colorFor: (value) => _parseColor(value.value),
        onSelected: controller.setBackgroundColor,
      ),
    );
  }
}

class _OrderToolPanel extends StatelessWidget {
  const _OrderToolPanel({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'merge.image.reorderHint'.tr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        _ReorderImageList(controller: controller),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  static const double _touchTargetHeight = 48;

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                value.round().toString(),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        SizedBox(
          height: _touchTargetHeight,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ColorChoiceSection<T> extends StatelessWidget {
  const _ColorChoiceSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.enabled,
    required this.labelFor,
    required this.onSelected,
    required this.colorFor,
  });

  final String title;
  final List<T> values;
  final T selected;
  final bool enabled;
  final String Function(T value) labelFor;
  final Color Function(T value) colorFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: values.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final value = values[index];
              final label = labelFor(value);
              final isSelected = selected == value;
              return Semantics(
                button: true,
                selected: isSelected,
                label: label,
                child: Tooltip(
                  message: label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: enabled ? () => onSelected(value) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorFor(value),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReorderImageList extends StatelessWidget {
  const _ReorderImageList({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    final images = controller.selectedImages;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      onReorder: controller.reorderSelectedImages,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final image = images[index];
        return ListTile(
          key: ValueKey('${image.path}#$index'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            controller.formatBytes(image.sizeBytes),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          trailing: ReorderableDragStartListener(
            index: index,
            enabled: !controller.isBusy.value,
            child: const Icon(Icons.drag_handle),
          ),
        );
      },
    );
  }
}

Color _parseColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

IconData _toolbarTabIcon(MergeToolbarTab tab) {
  return switch (tab) {
    MergeToolbarTab.layout => Icons.dashboard_customize_outlined,
    MergeToolbarTab.border => Icons.tune,
    MergeToolbarTab.background => Icons.format_color_fill_outlined,
    MergeToolbarTab.order => Icons.swap_vert_outlined,
  };
}
