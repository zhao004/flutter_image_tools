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
/// 执行导出，底部工具栏集中承载布局、间距、背景、缩放和排序，避免参数
/// 分散在页面卡片里影响连续编辑效率。
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
        exportLabel: 'merge.action.merge'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImages,
        onExport: controller.merge,
        imageMeta: images.isEmpty
            ? null
            : '${'merge.image.selectedCount'.trParams({'count': images.length.toString()})} · ${controller.formatBytes(controller.totalSizeBytes)}',
        previewBuilder: (context, _) => _MergePreview(controller: controller),
        toolbar: _MergeToolbar(controller: controller),
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

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 560),
        child: AspectRatio(
          aspectRatio: _previewAspectRatio(controller.mode.value),
          child: DecoratedBox(
            decoration: BoxDecoration(color: backgroundColor),
            child: Padding(
              padding: EdgeInsets.all(math.max(spacing, 6)),
              child: _MergePreviewLayout(
                images: images,
                mode: controller.mode.value,
                columns: controller.columns.value,
                spacing: spacing,
                borderWidth: borderWidth,
                borderColor: borderColor,
                cornerRadius: cornerRadius,
              ),
            ),
          ),
        ),
      );
    });
  }

  double _previewAspectRatio(MergeMode mode) {
    return switch (mode) {
      MergeMode.horizontal => 16 / 9,
      MergeMode.vertical => 3 / 4,
      MergeMode.grid => 1,
    };
  }
}

class _MergePreviewLayout extends StatelessWidget {
  const _MergePreviewLayout({
    required this.images,
    required this.mode,
    required this.columns,
    required this.spacing,
    required this.borderWidth,
    required this.borderColor,
    required this.cornerRadius,
  });

  final List<LocalImageFile> images;
  final MergeMode mode;
  final int columns;
  final double spacing;
  final double borderWidth;
  final Color borderColor;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }
    return switch (mode) {
      MergeMode.horizontal => Row(
        children: _withSpacing(
          images.map((image) => Expanded(child: _tile(image))).toList(),
          isHorizontal: true,
        ),
      ),
      MergeMode.vertical => Column(
        children: _withSpacing(
          images.map((image) => Expanded(child: _tile(image))).toList(),
          isHorizontal: false,
        ),
      ),
      MergeMode.grid => LayoutBuilder(
        builder: (context, constraints) {
          final safeColumns = columns
              .clamp(1, math.max(1, images.length))
              .toInt();
          final rows = (images.length / safeColumns).ceil();
          return Column(
            children: List.generate(rows, (rowIndex) {
              final rowImages = images
                  .skip(rowIndex * safeColumns)
                  .take(safeColumns)
                  .toList(growable: false);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: rowIndex == rows - 1 ? 0 : spacing,
                  ),
                  child: Row(
                    children: [
                      ..._withSpacing(
                        rowImages
                            .map((image) => Expanded(child: _tile(image)))
                            .toList(),
                        isHorizontal: true,
                      ),
                      for (
                        var index = rowImages.length;
                        index < safeColumns;
                        index++
                      )
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    };
  }

  Widget _tile(LocalImageFile image) {
    return _PreviewImageTile(
      image: image,
      borderWidth: borderWidth,
      borderColor: borderColor,
      cornerRadius: cornerRadius,
    );
  }

  List<Widget> _withSpacing(
    List<Widget> children, {
    required bool isHorizontal,
  }) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(
          SizedBox(
            width: isHorizontal ? spacing : 0,
            height: isHorizontal ? 0 : spacing,
          ),
        );
      }
      spaced.add(children[index]);
    }
    return spaced;
  }
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
        ? Image.file(file, fit: BoxFit.cover)
        : ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Text(
                image.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: radius,
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

class _MergeToolbar extends StatelessWidget {
  const _MergeToolbar({required this.controller});

  final MergeController controller;

  @override
  Widget build(BuildContext context) {
    final maxToolbarHeight = math.min(
      MediaQuery.sizeOf(context).height * 0.32,
      260.0,
    );
    return SizedBox(
      height: maxToolbarHeight,
      child: Obx(
        () => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ToolbarTitle(
                title: 'merge.layout.title'.tr,
                trailing: 'merge.image.selectedCount'.trParams({
                  'count': controller.selectedImages.length.toString(),
                }),
              ),
              const SizedBox(height: 6),
              EditorOptionWrap<MergeMode>(
                values: MergeMode.values,
                selected: controller.mode.value,
                labelFor: (value) => value.labelKey.tr,
                enabled: !controller.isBusy.value,
                onSelected: controller.setMode,
              ),
              if (controller.mode.value == MergeMode.grid) ...[
                const SizedBox(height: 8),
                _LabeledSlider(
                  label: 'merge.layout.columns'.trParams({
                    'count': controller.columns.value.toString(),
                  }),
                  value: controller.columns.value.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: controller.isBusy.value
                      ? null
                      : controller.updateColumns,
                ),
              ],
              const SizedBox(height: 8),
              _LabeledSlider(
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
              const SizedBox(height: 8),
              _ChoiceSection<MergeBackgroundColor>(
                title: 'merge.layout.backgroundColor'.tr,
                values: MergeBackgroundColor.values,
                selected: controller.backgroundColor.value,
                enabled: !controller.isBusy.value,
                labelFor: (value) => value.labelKey.tr,
                colorFor: (value) => _parseColor(value.value),
                onSelected: controller.setBackgroundColor,
              ),
              const SizedBox(height: 8),
              _ChoiceSection<MergeScaleMode>(
                title: 'merge.layout.scaleMode'.tr,
                values: MergeScaleMode.values,
                selected: controller.scaleMode.value,
                enabled: !controller.isBusy.value,
                labelFor: (value) => value.labelKey.tr,
                onSelected: controller.setScaleMode,
              ),
              const SizedBox(height: 4),
              Text(
                'merge.layout.scaleHint'.tr,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _LabeledSlider(
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
              _ChoiceSection<MergeBorderColor>(
                title: 'merge.layout.borderColor'.tr,
                values: MergeBorderColor.values,
                selected: controller.borderColor.value,
                enabled: !controller.isBusy.value,
                labelFor: (value) => value.labelKey.tr,
                colorFor: (value) => _parseColor(value.value),
                onSelected: controller.setBorderColor,
              ),
              if (controller.selectedImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('merge.image.reorderHint'.tr),
                const SizedBox(height: 4),
                _ReorderImageList(controller: controller),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarTitle extends StatelessWidget {
  const _ToolbarTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

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
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SizedBox(
          height: 32,
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

class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.enabled,
    required this.labelFor,
    required this.onSelected,
    this.colorFor,
  });

  final String title;
  final List<T> values;
  final T selected;
  final bool enabled;
  final String Function(T value) labelFor;
  final Color Function(T value)? colorFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: values
                .map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: colorFor == null
                          ? null
                          : CircleAvatar(
                              backgroundColor: colorFor!(value),
                              radius: 8,
                            ),
                      label: Text(labelFor(value)),
                      selected: selected == value,
                      onSelected: enabled ? (_) => onSelected(value) : null,
                    ),
                  ),
                )
                .toList(growable: false),
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
