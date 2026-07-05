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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Toolkit'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => controller.openTool(controller.tools[2]),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverToBoxAdapter(
                child: _HeaderCard(colorScheme: colorScheme),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  onChanged: controller.updateQuery,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索工具',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '功能入口',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.recentTools
                      .map(
                        (tool) => ActionChip(
                          avatar: Icon(_iconFor(tool.icon), size: 18),
                          label: Text(tool.title),
                          onPressed: () => controller.openTool(tool),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '最近图片',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Obx(() {
                  if (controller.recentFiles.isEmpty) {
                    return const Text('选择图片后会显示在这里');
                  }
                  return SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.recentFiles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = controller.recentFiles[index];
                        return Chip(
                          avatar: const Icon(Icons.image_outlined, size: 18),
                          label: SizedBox(
                            width: 140,
                            child: Text(
                              file.fileName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '全部工具',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Obx(
              () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.12,
                  ),
                  itemCount: controller.filteredTools.length,
                  itemBuilder: (context, index) {
                    final tool = controller.filteredTools[index];
                    return _ToolCard(
                      tool: tool,
                      onTap: () => controller.openTool(tool),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String key) => _toolIconFor(key);
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: colorScheme.onPrimaryContainer),
            const SizedBox(height: 12),
            Text(
              '本地离线图片工具',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '图片只在手机本地处理，不上传服务器；已开放压缩、裁剪、拼接、滤镜等本地处理能力。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, required this.onTap});

  final HomeToolItem tool;
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _toolIconFor(tool.icon),
                color: isAvailable ? colorScheme.primary : foreground,
              ),
              const Spacer(),
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
                Text(
                  '规划中',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
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
    'history' => Icons.history,
    'settings' => Icons.settings_outlined,
    'crop' => Icons.crop,
    'merge' => Icons.view_column_outlined,
    'resize' => Icons.aspect_ratio,
    'flip' => Icons.flip,
    'rotate' => Icons.rotate_90_degrees_ccw,
    'watermark' => Icons.branding_watermark_outlined,
    'filter' => Icons.filter_vintage_outlined,
    'grid' => Icons.grid_view_outlined,
    'convert' => Icons.swap_horiz,
    'pdf' => Icons.picture_as_pdf_outlined,
    'qrcode' => Icons.qr_code,
    'base64' => Icons.code,
    'color' => Icons.colorize_outlined,
    _ => Icons.image_outlined,
  };
}
