import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 工具任务入口模型，描述一个可独立完成的子流程。
class ToolTaskDestination {
  const ToolTaskDestination({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
}

/// 多功能工具的任务中心，只展示可进入的独立流程。
///
/// 构建设计：紧凑窗口使用单列列表，中等及以上窗口使用自适应网格；入口卡片
/// 保持固定的最小高度和完整语义，避免长文案或窗口缩放导致布局跳动。
class ToolTaskHubScaffold extends StatelessWidget {
  const ToolTaskHubScaffold({
    super.key,
    required this.title,
    required this.destinations,
  });

  static const double _maxContentWidth = 920;
  static const double _mediumWidth = 600;

  final String title;
  final List<ToolTaskDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMedium = constraints.maxWidth >= _mediumWidth;
            final padding = isMedium ? 24.0 : 16.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: GridView.builder(
                  padding: EdgeInsets.all(padding),
                  itemCount: destinations.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMedium ? 2 : 1,
                    mainAxisExtent: 136,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('task-hub-${destination.route}'),
                        onTap: () => Get.toNamed(destination.route),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: SizedBox.square(
                                  dimension: 56,
                                  child: Icon(
                                    destination.icon,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      destination.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 独立工具流程的自适应页面骨架。
///
/// 构建设计：840dp 以下按主内容、分隔线、辅助内容顺序滚动；宽屏改为 2:1
/// 支撑面板布局并限制总宽度。页面只管理布局，业务异常和忙碌状态由控制器处理。
class AdaptiveTaskScaffold extends StatelessWidget {
  const AdaptiveTaskScaffold({
    super.key,
    required this.title,
    required this.primary,
    required this.secondary,
    this.actions = const <Widget>[],
  });

  static const double _expandedWidth = 840;
  static const double _maxContentWidth = 1040;

  final String title;
  final Widget primary;
  final Widget secondary;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isExpanded = constraints.maxWidth >= _expandedWidth;
            final padding = isExpanded ? 24.0 : 16.0;
            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: isExpanded
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: primary),
                            const SizedBox(width: 24),
                            VerticalDivider(
                              width: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: secondary),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            primary,
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Divider(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            secondary,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 工具页的无卡片分区标题，避免在页面区块中继续嵌套卡片。
class ToolTaskSection extends StatelessWidget {
  const ToolTaskSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
