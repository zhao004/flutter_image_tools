import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'logs_controller.dart';

/// 日志管理页，展示本地任务诊断日志和清理入口。
///
/// 构建设计：日志字段较长，列表优先展示功能、状态、耗时和路径摘要；用户可
/// 通过搜索、状态和日期快速缩小范围，后续可继续扩展导出能力。
class LogsView extends GetView<LogsController> {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志管理'),
        actions: [
          IconButton(
            tooltip: '清理日志',
            onPressed: () => _confirmClearLogs(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadLogs,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LogsFilters(controller: controller),
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
                          const Icon(Icons.article_outlined, size: 48),
                          const SizedBox(height: 12),
                          const Text('暂无操作日志'),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: controller.loadLogs,
                            child: const Text('刷新'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: controller.items
                      .map((item) {
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
                                [
                                  controller.formatDateTime(item.startedAt),
                                  controller.formatDuration(item.durationMs),
                                  item.outputPath ??
                                      item.errorMessage ??
                                      item.inputPath,
                                ].join(' · '),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(isSuccess ? '成功' : '失败'),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理操作日志'),
        content: const Text('此操作只清理本地诊断日志，不会删除历史记录或导出图片。'),
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
      await controller.clearLogs();
    }
  }
}

class _LogsFilters extends StatelessWidget {
  const _LogsFilters({required this.controller});

  final LogsController controller;

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
                hintText: '搜索功能、路径、参数或错误',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => SegmentedButton<LogsStatusFilter>(
                segments: LogsStatusFilter.values
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
                children: LogsDateFilter.values
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
