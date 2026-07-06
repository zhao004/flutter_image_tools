import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'logs_controller.dart';

/// 日志管理页，展示本地任务诊断日志、筛选条件、CSV 导出和清理入口。
///
/// 构建设计：日志字段较长，列表优先展示功能、状态、耗时和路径摘要；用户可
/// 通过搜索、状态和日期快速缩小范围，导出时复用当前筛选条件。
class LogsView extends GetView<LogsController> {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('logs.title'.tr),
        actions: [
          IconButton(
            tooltip: 'logs.export.tooltip'.tr,
            onPressed: controller.exportLogs,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'logs.clear.tooltip'.tr,
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
              _ExportResultCard(controller: controller),
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
                          Text('logs.empty'.tr),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: controller.loadLogs,
                            child: Text('common.refresh'.tr),
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
                              trailing: Text(
                                isSuccess
                                    ? 'logs.status.success'.tr
                                    : 'logs.status.failed'.tr,
                              ),
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
        title: Text('logs.clear.title'.tr),
        content: Text('logs.clear.message'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('common.clear'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearLogs();
    }
  }
}

class _ExportResultCard extends StatelessWidget {
  const _ExportResultCard({required this.controller});

  final LogsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final path = controller.exportedPath.value;
      if (path.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'logs.export.result.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('logs.export.result.body'.tr),
              const SizedBox(height: 8),
              Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    });
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
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'logs.search.hint'.tr,
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
                        label: Text(filter.labelKey.tr),
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
                        label: Text(filter.labelKey.tr),
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
