import 'dart:io';

import 'package:flutter/material.dart';

import '../models/local_image_file.dart';

/// 图片编辑底部一级工具模型。
///
/// 设计意图：所有图片编辑页共享“一级工具 + 可选二级工具”的数据结构，
/// 页面只负责提供业务回调，通用组件负责横向滚动、选中态和紧凑布局。
class ToolCategory {
  const ToolCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.subItems = const <ToolSubItem>[],
  });

  final String id;
  final String name;
  final IconData icon;
  final List<ToolSubItem> subItems;
}

/// 图片编辑底部二级工具模型。
class ToolSubItem {
  const ToolSubItem({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final IconData icon;
}

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
    this.imageMeta,
    this.resultSummary,
    this.appBarActions = const [],
    this.lockPreviewScroll = false,
    this.bottomToolbar,
    this.showEditingControlsWhenEmpty = false,
    this.showPreviewInfo = true,
    this.showDefaultAppBarActions = true,
    this.expandPreviewToAvailableHeight = false,
    this.overlayToolbar = true,
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
  final String? imageMeta;
  final Widget? resultSummary;
  final List<Widget> appBarActions;
  final bool lockPreviewScroll;
  final Widget? bottomToolbar;
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
            lockPreviewScroll: lockPreviewScroll,
            showPreviewInfo: showPreviewInfo,
            expandPreviewToAvailableHeight: expandPreviewToAvailableHeight,
          );
    final bottomToolbarSurface = bottomToolbar == null
        ? null
        : _EditorBottomToolbarSurface(child: bottomToolbar!);
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
            Column(children: [Expanded(child: previewContent)]),
            if (showEditingControls && bottomToolbarSurface != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: bottomToolbarSurface,
              ),
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
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EditorBottomToolbarSurface extends StatelessWidget {
  const _EditorBottomToolbarSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 图片编辑页统一动态底部工具栏。
///
/// 设计意图：用固定高度一级菜单承载工具入口，选中工具后在同一区域上方
/// 渲染对应属性面板；二级工具使用可选横向列表承载，避免每个页面重复维护
/// TabBar、属性面板和底部按钮三套布局。异常策略：组件不保存业务状态，所有
/// 选中、关闭、确认行为都交回页面控制器处理，避免通用层产生隐式状态。
class EditorDynamicToolPanel extends StatelessWidget {
  const EditorDynamicToolPanel({
    super.key,
    required this.categories,
    required this.activeCategoryId,
    required this.onCategorySelected,
    this.activeSubItemId,
    this.onSubItemSelected,
    this.activePanel,
    this.activePanelTitle,
    this.onClosePanel,
    this.onConfirmPanel,
    this.maxPanelHeight = 180,
    this.showPanelHeader = true,
    this.compactPanel = false,
  });

  final List<ToolCategory> categories;
  final String? activeCategoryId;
  final ValueChanged<ToolCategory> onCategorySelected;
  final String? activeSubItemId;
  final ValueChanged<ToolSubItem>? onSubItemSelected;
  final Widget? activePanel;
  final String? activePanelTitle;
  final VoidCallback? onClosePanel;
  final VoidCallback? onConfirmPanel;
  final double maxPanelHeight;
  final bool showPanelHeader;
  final bool compactPanel;

  @override
  Widget build(BuildContext context) {
    final activeCategory = _activeCategory;
    final hasActiveSubItems = activeCategory?.subItems.isNotEmpty ?? false;
    final shouldShowSubPanel = activePanel != null || hasActiveSubItems;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shouldShowSubPanel) ...[
          _DynamicToolSubPanel(
            title: activePanelTitle ?? activeCategory?.name,
            maxHeight: maxPanelHeight,
            subItems: activeCategory?.subItems ?? const <ToolSubItem>[],
            activeSubItemId: activeSubItemId,
            onSubItemSelected: onSubItemSelected,
            onClosePanel: onClosePanel,
            onConfirmPanel: onConfirmPanel,
            showHeader: showPanelHeader,
            compact: compactPanel,
            child: activePanel ?? const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 60,
          child: ListView.builder(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              return _PrimaryToolButton(
                category: item,
                selected: item.id == activeCategoryId,
                onTap: () => onCategorySelected(item),
              );
            },
          ),
        ),
      ],
    );
  }

  ToolCategory? get _activeCategory {
    for (final category in categories) {
      if (category.id == activeCategoryId) {
        return category;
      }
    }
    return null;
  }
}

class _DynamicToolSubPanel extends StatelessWidget {
  const _DynamicToolSubPanel({
    required this.title,
    required this.maxHeight,
    required this.subItems,
    required this.activeSubItemId,
    required this.onSubItemSelected,
    required this.onClosePanel,
    required this.onConfirmPanel,
    required this.showHeader,
    required this.compact,
    required this.child,
  });

  final String? title;
  final double maxHeight;
  final List<ToolSubItem> subItems;
  final String? activeSubItemId;
  final ValueChanged<ToolSubItem>? onSubItemSelected;
  final VoidCallback? onClosePanel;
  final VoidCallback? onConfirmPanel;
  final bool showHeader;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader &&
                  (title != null ||
                      onClosePanel != null ||
                      onConfirmPanel != null))
                Row(
                  children: [
                    if (onClosePanel != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: onClosePanel,
                        icon: const Icon(Icons.close),
                      ),
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      )
                    else
                      const Spacer(),
                    if (onConfirmPanel != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).okButtonLabel,
                        onPressed: onConfirmPanel,
                        icon: const Icon(Icons.check),
                      ),
                  ],
                ),
              if (subItems.isNotEmpty) ...[
                SizedBox(
                  height: 58,
                  child: ListView.builder(
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    itemCount: subItems.length,
                    itemBuilder: (context, index) {
                      final item = subItems[index];
                      return _SecondaryToolButton(
                        item: item,
                        selected: item.id == activeSubItemId,
                        onTap: () => onSubItemSelected?.call(item),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              child,
            ],
          ),
        ),
      );
    }

    final panelHeight = maxHeight.clamp(48, 64).toDouble();
    final subItemButtons = subItems
        .map(
          (item) => _SecondaryToolButton(
            item: item,
            selected: item.id == activeSubItemId,
            onTap: () => onSubItemSelected?.call(item),
          ),
        )
        .toList(growable: false);
    return SizedBox(
      height: panelHeight,
      child: Row(
        children: [
          if (showHeader &&
              (title != null ||
                  onClosePanel != null ||
                  onConfirmPanel != null)) ...[
            if (onClosePanel != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClosePanel,
                icon: const Icon(Icons.close),
              ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            if (onConfirmPanel != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).okButtonLabel,
                onPressed: onConfirmPanel,
                icon: const Icon(Icons.check),
              ),
          ],
          if (subItems.isNotEmpty)
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: subItemButtons),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryToolButton extends StatelessWidget {
  const _PrimaryToolButton({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ToolCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? colorScheme.primary : colorScheme.onSurface;
    return SizedBox(
      width: 72,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 24, color: foreground),
              const SizedBox(height: 4),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryToolButton extends StatelessWidget {
  const _SecondaryToolButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ToolSubItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(item.icon, size: 18),
        label: Text(item.name),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colorScheme.secondaryContainer,
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
