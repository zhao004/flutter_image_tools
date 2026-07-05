import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import 'favorites_controller.dart';

/// 收藏模板页，管理常用功能参数组合。
///
/// 构建设计：模板以功能名、模板名和 JSON 参数保存，保证不同图片工具都能
/// 复用同一套本地收藏结构；当前页面先提供管理闭环，后续可在各功能页快捷套用。
class FavoritesView extends GetView<FavoritesController> {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏模板'),
        actions: [
          IconButton(
            tooltip: '清空模板',
            onPressed: () => _confirmClearTemplates(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadTemplates,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TemplateFormCard(controller: controller),
              const SizedBox(height: 16),
              _TemplateListCard(controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearTemplates(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空收藏模板'),
        content: const Text('此操作只删除本地模板，不会影响历史记录和已导出图片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearTemplates();
    }
  }
}

class _TemplateFormCard extends StatelessWidget {
  const _TemplateFormCard({required this.controller});

  final FavoritesController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('新增模板', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<FavoriteFeaturePreset>(
                segments: FavoriteFeaturePreset.values
                    .map(
                      (item) =>
                          ButtonSegment(value: item, label: Text(item.label)),
                    )
                    .toList(growable: false),
                selected: {controller.feature.value},
                onSelectionChanged: controller.isLoading.value
                    ? null
                    : (values) => controller.setFeature(values.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.templateNameController,
                enabled: !controller.isLoading.value,
                decoration: const InputDecoration(
                  labelText: '模板名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.parametersController,
                enabled: !controller.isLoading.value,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '参数 JSON',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.isLoading.value
                    ? null
                    : controller.createTemplate,
                icon: controller.isLoading.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.star_border),
                label: Text(controller.isLoading.value ? '处理中' : '保存模板'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateListCard extends StatelessWidget {
  const _TemplateListCard({required this.controller});

  final FavoritesController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: controller.updateKeyword,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索功能、模板名或参数',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              if (controller.isLoading.value && controller.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('暂无收藏模板')),
                );
              }
              return Column(
                children: controller.items
                    .map(
                      (item) =>
                          _TemplateTile(item: item, controller: controller),
                    )
                    .toList(growable: false),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.item, required this.controller});

  final FavoriteTemplate item;
  final FavoritesController controller;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.star_outline),
      title: Text(item.templateName),
      subtitle: Text(
        '${item.featureName} · ${controller.formatDateTime(item.updatedAt)}',
      ),
      trailing: IconButton(
        tooltip: '删除模板',
        onPressed: () => _confirmDelete(context),
        icon: const Icon(Icons.delete_outline),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(controller.compactJson(item.parametersJson)),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除“${item.templateName}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteTemplate(item);
    }
  }
}
