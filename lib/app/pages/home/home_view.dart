import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_controller.dart';

/// 首页视图，展示离线图片工具入口、搜索和最近常用区域。
///
/// 构建设计：使用 Sliver 保持长列表滚动性能，宫格根据宽度自适应列数；
/// 未完成模块保持可见但禁用，避免用户误以为功能缺失。
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app.title'.tr),
        actions: [
          IconButton(
            tooltip: 'home.tool.settings.title'.tr,
            onPressed: controller.openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const contentMaxWidth = 1120.0;
            final width = constraints.maxWidth;
            final pagePadding = width >= 840 ? 24.0 : 16.0;
            final contentWidth = math.min(
              contentMaxWidth,
              math.max(0.0, width - pagePadding * 2),
            );
            final sideInset = (width - contentWidth) / 2;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          onChanged: controller.updateQuery,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'home.search.hint'.tr,
                            suffixIcon: const Icon(Icons.tune_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _SectionHeader(
                          icon: Icons.star_outline,
                          titleKey: 'home.section.favorites',
                          subtitleKey: 'home.section.favorites.subtitle',
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Obx(() {
                        if (controller.favoriteTools.isEmpty) {
                          return _EmptyPanel(
                            icon: Icons.star_border,
                            message: 'home.favorites.empty'.tr,
                          );
                        }
                        return _ToolChipWrap(
                          tools: controller.favoriteTools,
                          onTap: controller.openTool,
                        );
                      }),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _SectionHeader(
                          icon: Icons.grid_view_outlined,
                          titleKey: 'home.section.allTools',
                          subtitleKey: 'home.section.allTools.subtitle',
                        ),
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => SliverPadding(
                    padding: EdgeInsets.fromLTRB(sideInset, 0, sideInset, 28),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 236,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.04,
                          ),
                      itemCount: controller.filteredTools.length,
                      itemBuilder: (context, index) {
                        final tool = controller.filteredTools[index];
                        return Obx(
                          () => _ToolCard(
                            tool: tool,
                            isFavorite: controller.isFavoriteTool(tool),
                            onToggleFavorite: () =>
                                controller.toggleFavoriteTool(tool),
                            onTap: () => controller.openTool(tool),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });

  final IconData icon;
  final String titleKey;
  final String subtitleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleKey.tr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleKey.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolChipWrap extends StatelessWidget {
  const _ToolChipWrap({required this.tools, required this.onTap});

  final Iterable<HomeToolItem> tools;
  final ValueChanged<HomeToolItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tools
          .map(
            (tool) => ActionChip(
              avatar: Icon(_toolIconFor(tool.icon), size: 18),
              label: Text(tool.title),
              onPressed: () => onTap(tool),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final HomeToolItem tool;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = tool.availability == ToolAvailability.available;
    final colorScheme = theme.colorScheme;
    final foreground = isAvailable
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.48);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _toolIconFor(tool.icon),
                      color: isAvailable
                          ? colorScheme.onPrimaryContainer
                          : foreground,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: isFavorite
                        ? 'home.favorite.remove'.tr
                        : 'home.favorite.add'.tr,
                    onPressed: isAvailable ? onToggleFavorite : null,
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? colorScheme.primary : foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tool.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
              if (!isAvailable) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'home.planned.badge'.tr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _toolIconFor(String key) {
  return switch (key) {
    'compress' => Icons.compress,
    'batch' => Icons.playlist_add_check_outlined,
    'history' => Icons.history,
    'settings' => Icons.settings_outlined,
    'crop' => Icons.crop,
    'merge' => Icons.view_column_outlined,
    'resize' => Icons.aspect_ratio,
    'flip' => Icons.flip,
    'rotate' => Icons.rotate_90_degrees_ccw,
    'watermark' => Icons.branding_watermark_outlined,
    'imageWatermark' => Icons.layers_outlined,
    'filter' => Icons.filter_vintage_outlined,
    'annotation' => Icons.edit_outlined,
    'grid' => Icons.grid_view_outlined,
    'convert' => Icons.swap_horiz,
    'exif' => Icons.info_outline,
    'pdf' => Icons.picture_as_pdf_outlined,
    'qrcode' => Icons.qr_code,
    'gif' => Icons.gif_box_outlined,
    'base64' => Icons.code,
    'color' => Icons.colorize_outlined,
    _ => Icons.image_outlined,
  };
}
