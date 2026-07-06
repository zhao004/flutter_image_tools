import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
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
        title: Text('history.title'.tr),
        actions: [
          IconButton(
            tooltip: 'history.clear.tooltip'.tr,
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
                          Text('history.empty'.tr),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: controller.loadHistory,
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
                                item.outputPath ??
                                    item.errorMessage ??
                                    item.inputPath,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isSuccess
                                        ? 'history.status.success'.tr
                                        : 'history.status.failed'.tr,
                                  ),
                                  IconButton(
                                    tooltip: 'history.delete.tooltip'.tr,
                                    onPressed: () =>
                                        _confirmDeleteHistory(context, item),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
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

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('history.clear.title'.tr),
        content: Text('history.clear.message'.tr),
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
      await controller.clearHistory();
    }
  }

  Future<void> _confirmDeleteHistory(
    BuildContext context,
    OperationHistoryData item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('history.delete.title'.tr),
        content: Text(
          'history.delete.message'.trParams({'feature': item.featureName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('common.delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteHistoryItem(item);
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
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'history.search.hint'.tr,
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
                children: HistoryDateFilter.values
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
