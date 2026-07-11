import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/local_image_file.dart';

/// 图片编辑工作台视觉常量。
///
/// 设计意图：画布在浅色和深色主题下都保持稳定的中性深色，避免图片周围
/// 背景随系统主题跳变；工具栏和动作按钮继续使用 Material 3 语义色。
class _EditorVisualTokens {
  const _EditorVisualTokens._();

  static const Color canvasColor = Color(0xFF191B20);
  static const Color canvasPanelColor = Color(0xE62A2E34);
  static const Color canvasPanelBorderColor = Color(0x33FFFFFF);
  static const Color previewBackdropColor = Color(0xFF252A30);
  static const Color canvasTextColor = Color(0xFFF4F6F8);
  static const Color canvasMutedTextColor = Color(0xFFB9C0C8);

  static const double maxContentWidth = 920;
  static const double stagePadding = 16;
  static const double primaryToolbarHeight = 72;
}

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

/// 图片编辑页通用工作台。
///
/// 构建设计：顶部集中放置辅助操作和主导出动作，中间使用沉浸式深色画布，
/// 参数面板与一级工具坞固定在底部。异常策略：组件只负责展示与触发回调，
/// 不持有文件处理状态，业务校验和导出异常继续由各页面控制器处理。
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
    this.showRepickAction = true,
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
  final String? imageMeta;
  final Widget? resultSummary;
  final List<Widget> appBarActions;
  final bool lockPreviewScroll;
  final Widget? bottomToolbar;
  final bool showEditingControlsWhenEmpty;
  final bool showPreviewInfo;
  final bool showDefaultAppBarActions;
  final bool showRepickAction;
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
        : _EditorBottomToolbarSurface(
            elevated: overlayToolbar,
            child: bottomToolbar!,
          );
    final shouldShowToolbar =
        showEditingControls && bottomToolbarSurface != null;
    return Scaffold(
      backgroundColor: _EditorVisualTokens.canvasColor,
      appBar: AppBar(
        backgroundColor: _EditorVisualTokens.canvasColor,
        foregroundColor: _EditorVisualTokens.canvasTextColor,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: 0,
        iconTheme: const IconThemeData(
          color: _EditorVisualTokens.canvasTextColor,
          size: 26,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _EditorVisualTokens.canvasTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          ...appBarActions,
          if (showDefaultAppBarActions) ...[
            if (showRepickAction && image != null)
              IconButton(
                tooltip: repickLabel,
                onPressed: isBusy ? null : onPickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _EditorExportAction(
                label: exportLabel,
                icon: exportIcon,
                isBusy: isBusy,
                onPressed: image == null || isBusy ? null : onExport,
              ),
            ),
          ],
        ],
      ),
      body: ColoredBox(
        key: const ValueKey('editor-canvas-surface'),
        color: _EditorVisualTokens.canvasColor,
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                top: false,
                bottom: !shouldShowToolbar,
                child: previewContent,
              ),
            ),
            if (shouldShowToolbar) bottomToolbarSurface,
          ],
        ),
      ),
    );
  }
}

class _EditorExportAction extends StatelessWidget {
  const _EditorExportAction({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: onPressed == null
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimary,
      ),
    );
    return IconButton.filled(
      key: const ValueKey('editor-export-action'),
      tooltip: label,
      onPressed: onPressed,
      icon: isBusy ? progress : Icon(icon),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          key: const ValueKey('editor-empty-state'),
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.34),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(icon, size: 48, color: colorScheme.primaryFixed),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _EditorVisualTokens.canvasTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _EditorVisualTokens.canvasMutedTextColor,
                ),
              ),
              const SizedBox(height: 22),
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
            ? constraints.maxHeight
            : 560.0;
        final topInset = showPreviewInfo ? 76.0 : 20.0;
        final bottomInset = resultSummary == null ? 20.0 : 72.0;
        final contentHeight = math.max(
          0.0,
          availableHeight - topInset - bottomInset,
        );
        final previewFrame = _PreviewFrame(
          child: previewBuilder(context, image),
        );
        final expandedPreviewHeight = math.max(
          math.min(_minimumExpandedPreviewHeight, availableHeight),
          contentHeight,
        );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  physics: lockPreviewScroll
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: EdgeInsets.fromLTRB(
                    _EditorVisualTokens.stagePadding,
                    topInset,
                    _EditorVisualTokens.stagePadding,
                    bottomInset,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _EditorVisualTokens.maxContentWidth,
                      minHeight: contentHeight,
                    ),
                    child: Center(
                      child: expandPreviewToAvailableHeight
                          ? SizedBox(
                              height: expandedPreviewHeight,
                              child: Center(child: previewFrame),
                            )
                          : previewFrame,
                    ),
                  ),
                ),
              ),
            ),
            if (showPreviewInfo)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _EditorImageInfoOverlay(image: image, meta: meta),
                  ),
                ),
              ),
            if (resultSummary != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: _EditorCanvasOverlaySurface(
                      key: const ValueKey('editor-result-overlay'),
                      child: resultSummary!,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EditorImageInfoOverlay extends StatelessWidget {
  const _EditorImageInfoOverlay({required this.image, required this.meta});

  final LocalImageFile image;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final tooltip = meta == null ? image.name : '${image.name}\n$meta';
    return Tooltip(
      message: tooltip,
      child: _EditorCanvasOverlaySurface(
        key: const ValueKey('editor-image-info-overlay'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 18,
              color: _EditorVisualTokens.canvasMutedTextColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _EditorVisualTokens.canvasTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _EditorVisualTokens.canvasMutedTextColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorCanvasOverlaySurface extends StatelessWidget {
  const _EditorCanvasOverlaySurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _EditorVisualTokens.canvasPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _EditorVisualTokens.canvasPanelBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: child,
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('editor-preview-frame'),
      decoration: BoxDecoration(
        color: _EditorVisualTokens.previewBackdropColor,
        border: Border.all(color: _EditorVisualTokens.canvasPanelBorderColor),
      ),
      child: ClipRect(child: child),
    );
  }
}

class _EditorBottomToolbarSurface extends StatelessWidget {
  const _EditorBottomToolbarSurface({
    required this.elevated,
    required this.child,
  });

  final bool elevated;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        key: const ValueKey('editor-bottom-toolbar-surface'),
        decoration: BoxDecoration(
          color: elevated
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _EditorVisualTokens.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
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
/// TabBar、属性面板和底部按钮三套布局。异常策略：组件只保存当前导航的
/// 临时收起状态，业务选中、关闭、确认行为仍交回页面控制器处理。
class EditorDynamicToolPanel extends StatefulWidget {
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
    this.stackCompactPanel = false,
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
  final bool stackCompactPanel;

  @override
  State<EditorDynamicToolPanel> createState() => _EditorDynamicToolPanelState();
}

class _EditorDynamicToolPanelState extends State<EditorDynamicToolPanel> {
  bool _isPanelCollapsed = false;

  @override
  void didUpdateWidget(covariant EditorDynamicToolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeCategoryId != widget.activeCategoryId ||
        !_hasCollapsibleSubPanel) {
      // 切换导航或内容消失时恢复展开，避免新工具首次进入时继承旧折叠态。
      _isPanelCollapsed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportSize = MediaQuery.sizeOf(context);
    final isLandscape = viewportSize.width > viewportSize.height;
    final responsivePanelLimit = math.max(
      72.0,
      (viewportSize.height - kToolbarHeight) * (isLandscape ? 0.28 : 0.36),
    );
    final effectiveMaxPanelHeight = math.min(
      widget.maxPanelHeight,
      responsivePanelLimit,
    );
    final activeCategory = _activeCategory;
    final hasActiveSubItems = activeCategory?.subItems.isNotEmpty ?? false;
    final hasActivePanel =
        widget.activePanel != null && widget.activePanel is! SizedBox;
    final hasSubPanelContent = widget.activePanel != null || hasActiveSubItems;
    final shouldShowSubPanel = hasSubPanelContent && !_isPanelCollapsed;
    final compactSubPanelHeight = effectiveMaxPanelHeight
        .clamp(48, 64)
        .toDouble();
    final compactLayerCount =
        (hasActiveSubItems ? 1 : 0) + (hasActivePanel ? 1 : 0);
    final double stackedCompactHeight =
        (compactLayerCount * compactSubPanelHeight).toDouble() +
        (compactLayerCount > 1 ? 8.0 : 0.0);
    final compactPanelHeight = widget.stackCompactPanel
        ? stackedCompactHeight
        : compactSubPanelHeight;
    final double compactToolbarHeight = shouldShowSubPanel
        ? _EditorVisualTokens.primaryToolbarHeight + 8.0 + compactPanelHeight
        : _EditorVisualTokens.primaryToolbarHeight;
    final primaryTools = SizedBox(
      key: const ValueKey('editor-primary-tool-tabs'),
      height: _EditorVisualTokens.primaryToolbarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.categories
                    .map(
                      (item) => _PrimaryToolButton(
                        category: item,
                        selected: item.id == widget.activeCategoryId,
                        onTap: () => _handleCategoryTap(
                          item,
                          hasSubPanelContent: hasSubPanelContent,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          );
        },
      ),
    );
    if (widget.compactPanel) {
      return SizedBox(
        height: compactToolbarHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            primaryTools,
            if (shouldShowSubPanel)
              Positioned(
                key: const ValueKey('editor-compact-tool-panel'),
                left: 0,
                right: 0,
                bottom: _EditorVisualTokens.primaryToolbarHeight + 8,
                child: _DynamicToolSubPanel(
                  title: widget.activePanelTitle ?? activeCategory?.name,
                  maxHeight: effectiveMaxPanelHeight,
                  subItems: activeCategory?.subItems ?? const <ToolSubItem>[],
                  activeSubItemId: widget.activeSubItemId,
                  onSubItemSelected: widget.onSubItemSelected,
                  onClosePanel: widget.onClosePanel,
                  onConfirmPanel: widget.onConfirmPanel,
                  showHeader: widget.showPanelHeader,
                  compact: widget.compactPanel,
                  stackCompactPanel: widget.stackCompactPanel,
                  child: widget.activePanel ?? const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shouldShowSubPanel) ...[
          _ToolParameterSurface(
            child: _DynamicToolSubPanel(
              title: widget.activePanelTitle ?? activeCategory?.name,
              maxHeight: effectiveMaxPanelHeight,
              subItems: activeCategory?.subItems ?? const <ToolSubItem>[],
              activeSubItemId: widget.activeSubItemId,
              onSubItemSelected: widget.onSubItemSelected,
              onClosePanel: widget.onClosePanel,
              onConfirmPanel: widget.onConfirmPanel,
              showHeader: widget.showPanelHeader,
              compact: widget.compactPanel,
              stackCompactPanel: widget.stackCompactPanel,
              child: widget.activePanel ?? const SizedBox.shrink(),
            ),
          ),
        ],
        primaryTools,
      ],
    );
  }

  ToolCategory? get _activeCategory {
    for (final category in widget.categories) {
      if (category.id == widget.activeCategoryId) {
        return category;
      }
    }
    return null;
  }

  bool get _hasCollapsibleSubPanel {
    final activeCategory = _activeCategory;
    return widget.activePanel != null ||
        (activeCategory?.subItems.isNotEmpty ?? false);
  }

  void _handleCategoryTap(
    ToolCategory category, {
    required bool hasSubPanelContent,
  }) {
    if (category.id == widget.activeCategoryId) {
      if (!hasSubPanelContent) {
        widget.onCategorySelected(category);
        return;
      }
      setState(() => _isPanelCollapsed = !_isPanelCollapsed);
      return;
    }
    if (_isPanelCollapsed) {
      setState(() => _isPanelCollapsed = false);
    }
    widget.onCategorySelected(category);
  }
}

class _ToolParameterSurface extends StatelessWidget {
  const _ToolParameterSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('editor-tool-parameter-surface'),
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: child,
        ),
      ),
    );
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
    required this.stackCompactPanel,
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
  final bool stackCompactPanel;
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
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
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
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
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
    if (stackCompactPanel) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subItems.isNotEmpty) ...[
            _CompactToolOverlaySurface(
              height: panelHeight,
              child: ListView(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                children: subItemButtons,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (child is! SizedBox)
            _CompactToolOverlaySurface(
              height: panelHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: child,
              ),
            ),
        ],
      );
    }
    return _CompactToolOverlaySurface(
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
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
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
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
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

class _CompactToolOverlaySurface extends StatelessWidget {
  const _CompactToolOverlaySurface({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(height: height, child: child),
          ),
        ),
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
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: Tooltip(
        message: category.name,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 80,
              height: _EditorVisualTokens.primaryToolbarHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 40,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.secondaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(category.icon, size: 24, color: foreground),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
        avatar: Icon(
          item.icon,
          size: 18,
          color: selected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        label: Text(item.name),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colorScheme.secondaryContainer,
        showCheckmark: false,
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
        Image.file(
          File(image.path),
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return EditorImageLoadError(imageName: image.name);
          },
        ),
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

/// 统一图片加载失败占位。
///
/// 构建设计：大预览显示错误说明和文件名，小型缩略图只显示错误图标并通过
/// Tooltip 提供完整信息，避免在水印或拼接缩略图中产生文本溢出。
class EditorImageLoadError extends StatelessWidget {
  const EditorImageLoadError({super.key, required this.imageName});

  static const double _minimumDetailedWidth = 200;
  static const double _minimumDetailedHeight = 160;

  final String imageName;

  @override
  Widget build(BuildContext context) {
    final message = '${'common.imageLoadFailed'.tr}\n$imageName';
    return Tooltip(
      message: message,
      child: ColoredBox(
        color: _EditorVisualTokens.previewBackdropColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                !constraints.maxWidth.isFinite ||
                !constraints.maxHeight.isFinite ||
                constraints.maxWidth < _minimumDetailedWidth ||
                constraints.maxHeight < _minimumDetailedHeight;
            if (isCompact) {
              return const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 28,
                  color: _EditorVisualTokens.canvasMutedTextColor,
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: _EditorVisualTokens.canvasMutedTextColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'common.imageLoadFailed'.tr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _EditorVisualTokens.canvasTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      imageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _EditorVisualTokens.canvasMutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.28),
          ),
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
