import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import 'history_controller.dart';

/// 历史记录页，以每页二十条的 Sliver 列表展示本机图片处理记录。
///
/// 边界处理：空列表和读取失败均提供恢复入口；接近列表底部时请求下一页，
/// Controller 会拦截重复请求并在失败后保留已加载内容。
class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  static const double _loadMoreThreshold = 240;

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
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: RefreshIndicator(
            onRefresh: controller.loadHistory,
            child: CustomScrollView(
              key: const ValueKey('history-scroll-view'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _HistoryFilters(controller: controller),
                  ),
                ),
                Obx(() {
                  if (controller.isLoading.value && controller.items.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (controller.hasLoadError.value &&
                      controller.items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _HistoryEmptyState(
                        icon: Icons.error_outline,
                        message: 'history.load.failed.message'.tr,
                        onRefresh: controller.loadHistory,
                      ),
                    );
                  }
                  if (controller.items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _HistoryEmptyState(
                        icon: Icons.history,
                        message: 'history.empty'.tr,
                        onRefresh: controller.loadHistory,
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverList.builder(
                      itemCount: controller.items.length,
                      itemBuilder: (context, index) {
                        final item = controller.items[index];
                        return _HistoryItemCard(
                          key: ValueKey('history-item-${item.id}'),
                          item: item,
                          onDelete: () => _confirmDeleteHistory(context, item),
                        );
                      },
                    ),
                  );
                }),
                SliverToBoxAdapter(
                  child: Obx(
                    () => _HistoryPaginationFooter(
                      isEmpty: controller.items.isEmpty,
                      isLoadingMore: controller.isLoadingMore.value,
                      hasLoadMoreError: controller.hasLoadMoreError.value,
                      hasLoadError: controller.hasLoadError.value,
                      hasMore: controller.hasMore.value,
                      onLoadMore: controller.loadMoreHistory,
                      onRefresh: controller.loadHistory,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter <= _loadMoreThreshold &&
        (notification is ScrollUpdateNotification ||
            notification is OverscrollNotification)) {
      controller.loadMoreHistory();
    }
    return false;
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

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({
    super.key,
    required this.item,
    required this.onDelete,
  });

  final OperationHistoryData item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isSuccess = item.status == 'success';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
          ),
          title: Text(item.featureName),
          subtitle: Text(
            item.outputPath ?? item.errorMessage ?? item.inputPath,
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
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({
    required this.icon,
    required this.message,
    required this.onRefresh,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRefresh,
              child: Text('common.refresh'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPaginationFooter extends StatelessWidget {
  const _HistoryPaginationFooter({
    required this.isEmpty,
    required this.isLoadingMore,
    required this.hasLoadMoreError,
    required this.hasLoadError,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRefresh,
  });

  final bool isEmpty;
  final bool isLoadingMore;
  final bool hasLoadMoreError;
  final bool hasLoadError;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return const SizedBox.shrink();
    }
    if (isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('history.pagination.loading'.tr),
          ],
        ),
      );
    }
    if (hasLoadMoreError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.refresh),
            label: Text('history.pagination.retry'.tr),
          ),
        ),
      );
    }
    if (hasLoadError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text('history.load.failed.message'.tr),
          ),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(child: Text('history.pagination.end'.tr)),
      );
    }
    return const SizedBox(height: 32);
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
