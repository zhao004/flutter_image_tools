import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'batch_controller.dart';

/// 批量处理中心，当前提供批量压缩、格式转换、批量旋转、批量翻转、尺寸调整和队列控制。
///
/// 构建设计：选择、参数、队列状态和任务明细集中在同一页；暂停、继续、
/// 取消都只影响未开始任务，正在处理的单个本地任务会自然结束后再停队列。
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
            _OperationCard(controller: controller),
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
              Text('批量任务队列', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (images.isEmpty)
                const Text('请选择多张 JPG、PNG、WebP 或 BMP 图片，任务会按顺序本地处理。')
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

class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.controller});

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
              Text('处理类型', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BatchOperation.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.label),
                        selected: controller.operation.value == item,
                        onSelected: controller.isRunning.value
                            ? null
                            : (_) => controller.setOperation(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (controller.operation.value == BatchOperation.convert) ...[
                const SizedBox(height: 16),
                const Text('目标格式'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchConvertFormat.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: controller.convertFormat.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setConvertFormat(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value == BatchOperation.rotate) ...[
                const SizedBox(height: 16),
                const Text('旋转角度'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [-90, 90, 180, 270]
                      .map(
                        (item) => ChoiceChip(
                          label: Text('$item°'),
                          selected: controller.degrees.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setDegrees(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value == BatchOperation.flip) ...[
                const SizedBox(height: 16),
                const Text('翻转方向'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchFlipDirection.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: controller.flipDirection.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setFlipDirection(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value == BatchOperation.resize) ...[
                const SizedBox(height: 16),
                const Text('尺寸模式'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchResizeMode.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: controller.resizeMode.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setResizeMode(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
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
              Text('导出参数', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (controller.operation.value == BatchOperation.rotate) ...[
                Text('角度：${controller.degrees.value}°'),
                Slider(
                  value: controller.degrees.value.toDouble(),
                  min: -360,
                  max: 360,
                  divisions: 720,
                  label: '${controller.degrees.value}°',
                  onChanged: controller.isRunning.value
                      ? null
                      : (value) => controller.setDegrees(value.round()),
                ),
              ] else if (controller.operation.value == BatchOperation.flip) ...[
                Text('方向：${controller.flipDirection.value.label}'),
              ] else if (controller.operation.value ==
                  BatchOperation.resize) ...[
                if (controller.resizeMode.value == BatchResizeMode.percent) ...[
                  Text('缩放比例：${controller.resizePercent.value}%'),
                  Slider(
                    value: controller.resizePercent.value.toDouble(),
                    min: 10,
                    max: 300,
                    divisions: 58,
                    label: '${controller.resizePercent.value}%',
                    onChanged: controller.isRunning.value
                        ? null
                        : controller.updateResizePercent,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(controller.resizeWidth.value),
                          initialValue: controller.resizeWidth.value.toString(),
                          enabled: !controller.isRunning.value,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '宽度',
                            suffixText: 'px',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: controller.updateResizeWidth,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(controller.resizeHeight.value),
                          initialValue: controller.resizeHeight.value
                              .toString(),
                          enabled: !controller.isRunning.value,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '高度',
                            suffixText: 'px',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: controller.updateResizeHeight,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
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
              Text(controller.qualityHint()),
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
                  trailing: task.outputSizeBytes <= 0
                      ? null
                      : Text(controller.formatBytes(task.outputSizeBytes)),
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
