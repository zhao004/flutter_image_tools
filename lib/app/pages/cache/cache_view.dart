import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'cache_controller.dart';

/// 缓存管理页，展示缓存目录、文件数量、数据库记录数量和一键清理入口。
///
/// 构建设计：缓存目录可能随平台变化，因此页面展示实际目录路径；清理按钮
/// 删除应用临时目录子项，不触碰文档数据库和用户选择的源图片。
class CacheView extends GetView<CacheController> {
  const CacheView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('cache.title'.tr)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadSummary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(controller: controller),
              const SizedBox(height: 16),
              _ActionCard(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final CacheController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final summary = controller.summary.value;
          if (summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'cache.summary.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'cache.summary.files'.tr,
                value: 'cache.summary.filesValue'.trParams({
                  'count': summary.fileCount.toString(),
                }),
              ),
              _InfoRow(
                label: 'cache.summary.size'.tr,
                value: controller.formatBytes(summary.totalSizeBytes),
              ),
              _InfoRow(
                label: 'cache.summary.records'.tr,
                value: 'cache.summary.recordsValue'.trParams({
                  'count': summary.recordCount.toString(),
                }),
              ),
              const SizedBox(height: 8),
              Text(
                summary.cacheDirectoryPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.controller});

  final CacheController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final hasCache = controller.summary.value?.hasCache ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'cache.clear.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('cache.clear.body'.tr),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.isBusy.value || !hasCache
                    ? null
                    : controller.clearCache,
                icon: controller.isBusy.value
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cleaning_services_outlined),
                label: Text(
                  controller.isBusy.value
                      ? 'common.processing'.tr
                      : 'cache.clear.button'.tr,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
