import 'dart:io';

import 'package:flutter/material.dart';

import '../models/local_image_file.dart';

/// 图片编辑页通用骨架：选图前显示空状态，选图后展示统一五段式编辑布局。
///
/// 设计意图：滤镜、水印、裁剪、尺寸调整、翻转和旋转都遵循“先选图、
/// 实时预览、标签切换、属性编辑”的交互，统一布局可以减少重复代码并保持
/// 后续工具扩展一致。异常策略：组件只负责展示与触发回调，不持有文件处理状态，
/// 避免通用层吞掉各工具控制器自己的校验和错误处理。
class ImageEditorScaffold extends StatelessWidget {
  const ImageEditorScaffold({
    super.key,
    required this.title,
    required this.selectedImage,
    required this.isBusy,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.pickLabel,
    required this.repickLabel,
    required this.exportLabel,
    required this.exportIcon,
    required this.onPickImage,
    this.onExport,
    required this.previewBuilder,
    this.toolbar,
    this.imageMeta,
    this.resultSummary,
    this.appBarActions = const [],
    this.previewBorderRadius = 24,
    this.lockPreviewScroll = false,
    this.tabBar,
    this.bottomToolbar,
    this.toolbarMaxHeight,
    this.showEditingControlsWhenEmpty = false,
    this.showPreviewInfo = true,
    this.showDefaultAppBarActions = true,
    this.expandPreviewToAvailableHeight = false,
    this.overlayToolbar = false,
  });

  final String title;
  final LocalImageFile? selectedImage;
  final bool isBusy;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String pickLabel;
  final String repickLabel;
  final String exportLabel;
  final IconData exportIcon;
  final VoidCallback onPickImage;
  final VoidCallback? onExport;
  final Widget Function(BuildContext context, LocalImageFile image)
  previewBuilder;
  final Widget? toolbar;
  final String? imageMeta;
  final Widget? resultSummary;
  final List<Widget> appBarActions;
  final double previewBorderRadius;
  final bool lockPreviewScroll;
  final Widget? tabBar;
  final Widget? bottomToolbar;
  final double? toolbarMaxHeight;
  final bool showEditingControlsWhenEmpty;
  final bool showPreviewInfo;
  final bool showDefaultAppBarActions;
  final bool expandPreviewToAvailableHeight;
  final bool overlayToolbar;

  @override
  Widget build(BuildContext context) {
    final image = selectedImage;
    final showEditingControls = image != null || showEditingControlsWhenEmpty;
    final previewContent = image == null
        ? _EditorEmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
            buttonLabel: pickLabel,
            isBusy: isBusy,
            onPickImage: onPickImage,
          )
        : _EditorPreviewStage(
            image: image,
            meta: imageMeta,
            previewBuilder: previewBuilder,
            resultSummary: resultSummary,
            previewBorderRadius: previewBorderRadius,
            lockPreviewScroll: lockPreviewScroll,
            showPreviewInfo: showPreviewInfo,
            expandPreviewToAvailableHeight: expandPreviewToAvailableHeight,
          );
    final toolbarSurface = toolbar == null
        ? null
        : _EditorPropertyPanelSurface(
            maxHeight: toolbarMaxHeight,
            child: toolbar!,
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showDefaultAppBarActions) ...[
            if (image != null)
              IconButton(
                tooltip: repickLabel,
                onPressed: isBusy ? null : onPickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            IconButton(
              tooltip: exportLabel,
              onPressed: image == null || isBusy ? null : onExport,
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(exportIcon),
            ),
          ],
          ...appBarActions,
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: previewContent),
                if (showEditingControls) ...[
                  if (tabBar != null) _EditorTabBarSurface(child: tabBar!),
                  if (!overlayToolbar && toolbarSurface != null) toolbarSurface,
                  if (bottomToolbar != null)
                    _EditorBottomToolbarSurface(child: bottomToolbar!),
                ],
              ],
            ),
            if (showEditingControls && overlayToolbar && toolbarSurface != null)
              Positioned(left: 0, right: 0, bottom: 0, child: toolbarSurface),
          ],
        ),
      ),
    );
  }
}

class _EditorEmptyState extends StatelessWidget {
  const _EditorEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.isBusy,
    required this.onPickImage,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final bool isBusy;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 72, color: colorScheme.primary),
                  const SizedBox(height: 18),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: isBusy ? null : onPickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(buttonLabel),
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

class _EditorPreviewStage extends StatelessWidget {
  const _EditorPreviewStage({
    required this.image,
    required this.previewBuilder,
    required this.meta,
    required this.resultSummary,
    required this.previewBorderRadius,
    required this.lockPreviewScroll,
    required this.showPreviewInfo,
    required this.expandPreviewToAvailableHeight,
  });

  static const double _stagePadding = 16;
  static const double _previewInfoReservedHeight = 52;
  static const double _resultSummaryReservedHeight = 48;
  static const double _minimumExpandedPreviewHeight = 160;

  final LocalImageFile image;
  final Widget Function(BuildContext context, LocalImageFile image)
  previewBuilder;
  final String? meta;
  final Widget? resultSummary;
  final double previewBorderRadius;
  final bool lockPreviewScroll;
  final bool showPreviewInfo;
  final bool expandPreviewToAvailableHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - _stagePadding * 2
            : null;
        final previewFrame = _PreviewFrame(
          borderRadius: previewBorderRadius,
          child: previewBuilder(context, image),
        );
        final reservedHeight =
            (showPreviewInfo ? _previewInfoReservedHeight : 0) +
            (resultSummary == null ? 0 : _resultSummaryReservedHeight);
        final expandedPreviewHeight = availableHeight == null
            ? null
            : (availableHeight - reservedHeight).clamp(
                _minimumExpandedPreviewHeight,
                availableHeight,
              );

        return Center(
          child: SingleChildScrollView(
            physics: lockPreviewScroll
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: const EdgeInsets.all(_stagePadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 920,
                minHeight: availableHeight ?? 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (expandPreviewToAvailableHeight &&
                      expandedPreviewHeight != null)
                    SizedBox(
                      height: expandedPreviewHeight,
                      child: Center(child: previewFrame),
                    )
                  else
                    previewFrame,
                  if (showPreviewInfo) ...[
                    const SizedBox(height: 12),
                    Text(
                      image.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                  if (resultSummary != null) ...[
                    const SizedBox(height: 10),
                    resultSummary!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child, required this.borderRadius});

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

class _EditorTabBarSurface extends StatelessWidget {
  const _EditorTabBarSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: child,
      ),
    );
  }
}

class _EditorPropertyPanelSurface extends StatelessWidget {
  const _EditorPropertyPanelSurface({
    required this.child,
    required this.maxHeight,
  });

  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final maxPanelHeight =
        maxHeight ??
        (MediaQuery.sizeOf(context).height * 0.28).clamp(120.0, 240.0);
    final panel = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxPanelHeight),
        child: panel,
      ),
    );
  }
}

class _EditorBottomToolbarSurface extends StatelessWidget {
  const _EditorBottomToolbarSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: child,
        ),
      ),
    );
  }
}

/// 按图片原始比例显示本地图片，外层按可用空间自适应最大宽高。
class EditorImagePreview extends StatelessWidget {
  const EditorImagePreview({
    super.key,
    required this.image,
    this.colorFilter,
    this.transform,
    this.child,
    this.fit = BoxFit.contain,
  });

  final LocalImageFile image;
  final ColorFilter? colorFilter;
  final Matrix4? transform;
  final Widget? child;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = image.hasValidDimensions && image.height > 0
        ? image.width / image.height
        : 1.0;
    final preview = Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(image.path), fit: fit),
        ?child,
      ],
    );
    final filteredPreview = colorFilter == null
        ? preview
        : ColorFiltered(colorFilter: colorFilter!, child: preview);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 560),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: transform == null
            ? filteredPreview
            : Transform(
                alignment: Alignment.center,
                transform: transform!,
                child: filteredPreview,
              ),
      ),
    );
  }
}

/// 底部工具栏通用横向选项组，适合滤镜、方向、比例等枚举选择。
class EditorOptionWrap<T> extends StatelessWidget {
  const EditorOptionWrap({
    super.key,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    required this.enabled,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labelFor(item)),
                  selected: selected == item,
                  onSelected: enabled ? (_) => onSelected(item) : null,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

/// 单工具编辑页通用标签栏，用于压缩、格式转换、裁剪等只有一个参数面板的页面。
///
/// 设计意图：这些页面仍遵循五段式结构，但不需要多标签切换；用固定选中的
/// Chip 保持视觉层级一致，同时避免每个页面重复实现相同的横向容器。
class EditorSingleToolTab extends StatelessWidget {
  const EditorSingleToolTab({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            selected: true,
            onSelected: (_) {},
          ),
        ],
      ),
    );
  }
}

/// 导出结果摘要，用于编辑页预览区下方展示最近一次输出。
class EditorResultPill extends StatelessWidget {
  const EditorResultPill({
    super.key,
    required this.title,
    required this.detail,
    required this.tooltip,
  });

  final String title;
  final String detail;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$title · $detail',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
