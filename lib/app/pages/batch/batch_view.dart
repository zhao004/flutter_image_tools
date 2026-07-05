import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'batch_controller.dart';

/// 批量处理中心，当前提供批量压缩队列和队列控制。
///
/// 构建设计：选择、参数、队列状态和任务明细集中在同一页；暂停、继续、
/// 取消都只影响未开始任务，正在处理的单个本地压缩任务会自然结束后再停队列。
class BatchView extends GetView<BatchController> {
  const BatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('批量处理')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PickerCard(controller: controller),
            const SizedBox(height: 16),
            _SettingsCard(controller: controller),
            const SizedBox(height: 16),
            _QueueActions(controller: controller),
            const SizedBox(height: 16),
            _QueueStatusCard(controller: controller),
            const SizedBox(height: 16),
            _TaskListCard(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({required this.controller});

  final BatchController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final images = controller.selectedImages;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('批量压缩队列', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (images.isEmpty)
                const Text('请选择多张 JPG、PNG 或 WebP 图片，任务会按顺序本地压缩。')
              else ...[
                Text('已选择 ${images.length} 张图片'),
                const SizedBox(height: 4),
                Text(
                  '总大小：${controller.formatBytes(controller.totalSizeBytes)}',
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isRunning.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(images.isEmpty ? '批量选择' : '重新选择'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.controller});

  final BatchController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('压缩参数', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('质量：${controller.quality.value}%'),
              Slider(
                value: controller.quality.value.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '${controller.quality.value}%',
                onChanged: controller.isRunning.value
                    ? null
                    : controller.updateQuality,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueActions extends StatelessWidget {
  const _QueueActions({required this.controller});

  final BatchController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: controller.isRunning.value
                ? null
                : controller.startQueue,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始队列'),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.isRunning.value && !controller.isPaused.value
                ? controller.pauseQueue
                : null,
            icon: const Icon(Icons.pause),
            label: const Text('暂停'),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.isPaused.value
                ? controller.resumeQueue
                : null,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('继续'),
          ),
          OutlinedButton.icon(
            onPressed: controller.tasks.isEmpty ? null : controller.cancelQueue,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('取消'),
          ),
          OutlinedButton.icon(
            onPressed: controller.failedCount > 0 && !controller.isRunning.value
                ? controller.retryFailed
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('重试失败'),
          ),
        ],
      ),
    );
  }
}

class _QueueStatusCard extends StatelessWidget {
  const _QueueStatusCard({required this.controller});

  final BatchController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.tasks.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('队列进度', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: controller.progress),
              const SizedBox(height: 8),
              Text(
                '已结束 ${controller.processedCount.value} / ${controller.tasks.length} 个任务',
              ),
              const SizedBox(height: 8),
              Text(
                '成功 ${controller.successCount}，失败 ${controller.failedCount}，暂停 ${controller.pausedCount}，取消 ${controller.canceledCount}',
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _TaskListCard extends StatelessWidget {
  const _TaskListCard({required this.controller});

  final BatchController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.tasks.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('任务明细', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...controller.tasks.map(
                (task) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconForStatus(task.status)),
                  title: Text(
                    task.source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(task.errorMessage ?? task.status.label),
                  trailing: task.result == null
                      ? null
                      : Text(
                          controller.formatBytes(task.result!.outputSizeBytes),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  IconData _iconForStatus(BatchTaskStatus status) {
    return switch (status) {
      BatchTaskStatus.pending => Icons.hourglass_empty,
      BatchTaskStatus.running => Icons.sync,
      BatchTaskStatus.paused => Icons.pause_circle_outline,
      BatchTaskStatus.success => Icons.check_circle_outline,
      BatchTaskStatus.failed => Icons.error_outline,
      BatchTaskStatus.canceled => Icons.cancel_outlined,
    };
  }
}
