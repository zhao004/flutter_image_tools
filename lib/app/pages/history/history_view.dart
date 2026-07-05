import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'history_controller.dart';

/// 历史记录页，展示本机图片处理记录。
///
/// 边界处理：空列表显示明确占位；读取失败后由后续日志体系记录，当前页面
/// 先保持可恢复刷新入口。
class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            tooltip: '清理历史',
            onPressed: () => _confirmClearHistory(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HistoryFilters(controller: controller),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (controller.items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history, size: 48),
                          const SizedBox(height: 12),
                          const Text('暂无处理记录'),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: controller.loadHistory,
                            child: const Text('刷新'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: controller.items.map((item) {
                    final isSuccess = item.status == 'success';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: Icon(
                            isSuccess
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                          ),
                          title: Text(item.featureName),
                          subtitle: Text(
                            item.outputPath ??
                                item.errorMessage ??
                                item.inputPath,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(isSuccess ? '成功' : '失败'),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理历史记录'),
        content: const Text('此操作只清理本地历史记录，不会删除已导出的图片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearHistory();
    }
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({required this.controller});

  final HistoryController controller;

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
                hintText: '搜索功能、路径或参数',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => SegmentedButton<HistoryStatusFilter>(
                segments: HistoryStatusFilter.values
                    .map(
                      (filter) => ButtonSegment(
                        value: filter,
                        label: Text(filter.label),
                      ),
                    )
                    .toList(growable: false),
                selected: {controller.statusFilter.value},
                onSelectionChanged: (values) =>
                    controller.updateStatusFilter(values.first),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HistoryDateFilter.values
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(filter.label),
                        selected: controller.dateFilter.value == filter,
                        onSelected: (_) => controller.updateDateFilter(filter),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
