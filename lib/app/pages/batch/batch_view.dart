import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'batch_controller.dart';

/// 批量处理中心，当前提供批量压缩、格式转换、批量旋转、批量翻转、尺寸调整、文字水印、图片水印、图片滤镜、图片裁剪、删除 EXIF、九宫格切图、二维码识别、Base64 导出和队列控制。
///
/// 构建设计：选择、参数、队列状态和任务明细集中在同一页；暂停、继续、
/// 取消都只影响未开始任务，正在处理的单个本地任务会自然结束后再停队列。
class BatchView extends GetView<BatchController> {
  const BatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('batch.title'.tr)),
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
              Text(
                'batch.queue.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (images.isEmpty)
                Text('batch.queue.empty'.tr)
              else ...[
                Text(
                  'batch.queue.selectedCount'.trParams({
                    'count': images.length.toString(),
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  'batch.queue.totalSize'.trParams({
                    'size': controller.formatBytes(controller.totalSizeBytes),
                  }),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.isRunning.value
                    ? null
                    : controller.pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  images.isEmpty
                      ? 'batch.action.pickImages'.tr
                      : 'batch.action.repickImages'.tr,
                ),
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
              Text(
                'batch.operation.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BatchOperation.values
                    .map(
                      (item) => ChoiceChip(
                        label: Text(controller.operationLabel(item)),
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
                Text('batch.convert.targetFormat'.tr),
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
                Text('batch.rotate.angle'.tr),
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
                Text('batch.flip.title'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchFlipDirection.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(controller.flipLabel(item)),
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
                Text('batch.resize.mode'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchResizeMode.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(controller.resizeModeLabel(item)),
                          selected: controller.resizeMode.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setResizeMode(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value ==
                  BatchOperation.textWatermark) ...[
                const SizedBox(height: 16),
                Text('batch.watermark.position'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchWatermarkPosition.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(controller.watermarkPositionLabel(item)),
                          selected: controller.watermarkPosition.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setWatermarkPosition(item),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                Text('batch.watermark.color'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchWatermarkColor.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(controller.watermarkColorLabel(item)),
                          selected: controller.watermarkColor.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setWatermarkColor(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value ==
                  BatchOperation.imageWatermark) ...[
                const SizedBox(height: 16),
                Text('batch.imageWatermark.image'.tr),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.imageWatermark.value?.name ??
                            'batch.imageWatermark.notSelected'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: controller.isRunning.value
                          ? null
                          : controller.pickImageWatermark,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text('batch.action.pickWatermark'.tr),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('batch.watermark.position'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchWatermarkPosition.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(controller.watermarkPositionLabel(item)),
                          selected:
                              controller.imageWatermarkPosition.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) =>
                                    controller.setImageWatermarkPosition(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value == BatchOperation.filter) ...[
                const SizedBox(height: 16),
                Text('batch.filter.title'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchFilterType.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(controller.filterLabel(item)),
                          selected: controller.filter.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setFilter(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value == BatchOperation.crop) ...[
                const SizedBox(height: 16),
                Text('batch.crop.ratio'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BatchCropPreset.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(
                            '${controller.cropPresetLabel(item)} '
                            '${controller.cropPresetRatioLabel(item)}',
                          ),
                          selected: controller.cropPreset.value == item,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setCropPreset(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (controller.operation.value == BatchOperation.grid) ...[
                const SizedBox(height: 16),
                Text('batch.grid.size'.tr),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [2, 3, 4, 5]
                      .map(
                        (size) => ChoiceChip(
                          label: Text('$size × $size'),
                          selected: controller.gridSize.value == size,
                          onSelected: controller.isRunning.value
                              ? null
                              : (_) => controller.setGridSize(size),
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
              Text(
                'batch.settings.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (controller.operation.value == BatchOperation.rotate) ...[
                Text(
                  'batch.settings.angle'.trParams({
                    'value': controller.degrees.value.toString(),
                  }),
                ),
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
                Text(
                  'batch.settings.direction'.trParams({
                    'value': controller.flipLabel(
                      controller.flipDirection.value,
                    ),
                  }),
                ),
              ] else if (controller.operation.value ==
                  BatchOperation.resize) ...[
                if (controller.resizeMode.value == BatchResizeMode.percent) ...[
                  Text(
                    'batch.settings.scalePercent'.trParams({
                      'value': controller.resizePercent.value.toString(),
                    }),
                  ),
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
                          decoration: InputDecoration(
                            labelText: 'batch.resize.width'.tr,
                            suffixText: 'px',
                            border: const OutlineInputBorder(),
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
                          decoration: InputDecoration(
                            labelText: 'batch.resize.height'.tr,
                            suffixText: 'px',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: controller.updateResizeHeight,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else if (controller.operation.value ==
                  BatchOperation.textWatermark) ...[
                TextFormField(
                  key: ValueKey(controller.watermarkText.value),
                  initialValue: controller.watermarkText.value,
                  enabled: !controller.isRunning.value,
                  maxLength: 80,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'batch.watermark.text'.tr,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: controller.updateWatermarkText,
                ),
                const SizedBox(height: 8),
                Text(
                  'batch.settings.fontSize'.trParams({
                    'value': controller.watermarkFontSize.value.toString(),
                  }),
                ),
                Slider(
                  value: controller.watermarkFontSize.value.toDouble(),
                  min: 12,
                  max: 160,
                  divisions: 74,
                  label: '${controller.watermarkFontSize.value}px',
                  onChanged: controller.isRunning.value
                      ? null
                      : controller.updateWatermarkFontSize,
                ),
                Text(
                  'batch.settings.opacity'.trParams({
                    'value': controller.watermarkOpacity.value.toString(),
                  }),
                ),
                Slider(
                  value: controller.watermarkOpacity.value.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${controller.watermarkOpacity.value}%',
                  onChanged: controller.isRunning.value
                      ? null
                      : controller.updateWatermarkOpacity,
                ),
              ] else if (controller.operation.value ==
                  BatchOperation.imageWatermark) ...[
                Text(
                  'batch.settings.opacity'.trParams({
                    'value': controller.imageWatermarkOpacity.value.toString(),
                  }),
                ),
                Slider(
                  value: controller.imageWatermarkOpacity.value.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${controller.imageWatermarkOpacity.value}%',
                  onChanged: controller.isRunning.value
                      ? null
                      : controller.updateImageWatermarkOpacity,
                ),
                Text(
                  'batch.settings.scale'.trParams({
                    'value': controller.imageWatermarkScale.value.toString(),
                  }),
                ),
                Slider(
                  value: controller.imageWatermarkScale.value.toDouble(),
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: '${controller.imageWatermarkScale.value}%',
                  onChanged: controller.isRunning.value
                      ? null
                      : controller.updateImageWatermarkScale,
                ),
                Text(
                  'batch.settings.rotation'.trParams({
                    'value': controller.imageWatermarkRotation.value.toString(),
                  }),
                ),
                Slider(
                  value: controller.imageWatermarkRotation.value.toDouble(),
                  min: -180,
                  max: 180,
                  divisions: 72,
                  label: '${controller.imageWatermarkRotation.value}°',
                  onChanged: controller.isRunning.value
                      ? null
                      : controller.updateImageWatermarkRotation,
                ),
              ] else if (controller.operation.value ==
                  BatchOperation.filter) ...[
                Text(
                  'batch.settings.filter'.trParams({
                    'value': controller.filterLabel(controller.filter.value),
                  }),
                ),
              ] else if (controller.operation.value == BatchOperation.crop) ...[
                if (controller.cropPreset.value == BatchCropPreset.custom) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(controller.cropRatioWidth.value),
                          initialValue: controller.cropRatioWidth.value
                              .toString(),
                          enabled: !controller.isRunning.value,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'batch.crop.ratioWidth'.tr,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: controller.updateCropRatioWidth,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(controller.cropRatioHeight.value),
                          initialValue: controller.cropRatioHeight.value
                              .toString(),
                          enabled: !controller.isRunning.value,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'batch.crop.ratioHeight'.tr,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: controller.updateCropRatioHeight,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'batch.settings.currentRatio'.trParams({
                      'value': controller.cropPresetRatioLabel(
                        controller.cropPreset.value,
                      ),
                    }),
                  ),
                ],
              ] else if (controller.operation.value ==
                  BatchOperation.removeExif) ...[
                Text('batch.mode.removeExif'.tr),
              ] else if (controller.operation.value == BatchOperation.grid) ...[
                Text(
                  'batch.settings.grid'.trParams({
                    'value':
                        '${controller.gridSize.value} × ${controller.gridSize.value}',
                  }),
                ),
              ] else if (controller.operation.value ==
                  BatchOperation.scanCode) ...[
                Text('batch.mode.scanCode'.tr),
              ] else if (controller.operation.value ==
                  BatchOperation.base64Encode) ...[
                Text('batch.mode.base64Encode'.tr),
              ] else ...[
                Text(
                  'batch.settings.quality'.trParams({
                    'value': controller.quality.value.toString(),
                  }),
                ),
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
            label: Text('batch.action.start'.tr),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.isRunning.value && !controller.isPaused.value
                ? controller.pauseQueue
                : null,
            icon: const Icon(Icons.pause),
            label: Text('batch.action.pause'.tr),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.isPaused.value
                ? controller.resumeQueue
                : null,
            icon: const Icon(Icons.play_circle_outline),
            label: Text('batch.action.resume'.tr),
          ),
          OutlinedButton.icon(
            onPressed: controller.tasks.isEmpty ? null : controller.cancelQueue,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text('batch.action.cancel'.tr),
          ),
          OutlinedButton.icon(
            onPressed: controller.failedCount > 0 && !controller.isRunning.value
                ? controller.retryFailed
                : null,
            icon: const Icon(Icons.refresh),
            label: Text('batch.action.retryFailed'.tr),
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
              Text(
                'batch.queueStatus.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: controller.progress),
              const SizedBox(height: 8),
              Text(
                'batch.queueStatus.processed'.trParams({
                  'processed': controller.processedCount.value.toString(),
                  'total': controller.tasks.length.toString(),
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'batch.queueStatus.summary'.trParams({
                  'success': controller.successCount.toString(),
                  'failed': controller.failedCount.toString(),
                  'paused': controller.pausedCount.toString(),
                  'canceled': controller.canceledCount.toString(),
                }),
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
              Text(
                'batch.tasks.title'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                  subtitle: Text(
                    _subtitleForTask(controller, task),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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

  String _subtitleForTask(BatchController controller, BatchImageTask task) {
    final error = task.errorMessage;
    if (error != null && error.isNotEmpty) {
      return error;
    }
    if (task.resultText.isNotEmpty) {
      return 'batch.tasks.resultText'.trParams({
        'label': task.resultLabel,
        'text': task.resultText,
      });
    }
    if (task.resultLabel.isNotEmpty && task.status == BatchTaskStatus.success) {
      return task.resultLabel;
    }
    return controller.taskStatusLabel(task.status);
  }
}
