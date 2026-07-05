import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/compressed_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum BatchTaskStatus {
  pending(label: '等待'),
  running(label: '处理中'),
  paused(label: '已暂停'),
  success(label: '成功'),
  failed(label: '失败'),
  canceled(label: '已取消');

  const BatchTaskStatus({required this.label});

  final String label;
}

class BatchCompressionTask {
  const BatchCompressionTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.status = BatchTaskStatus.pending,
  });

  final LocalImageFile source;
  final CompressedImageFile? result;
  final String? errorMessage;
  final BatchTaskStatus status;

  bool get isTerminal =>
      status == BatchTaskStatus.success ||
      status == BatchTaskStatus.failed ||
      status == BatchTaskStatus.canceled;

  bool get canRetry => status == BatchTaskStatus.failed;

  BatchCompressionTask copyWith({
    CompressedImageFile? result,
    String? errorMessage,
    BatchTaskStatus? status,
    bool clearError = false,
  }) {
    return BatchCompressionTask(
      source: source,
      result: result ?? this.result,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }
}

/// 批量处理控制器，提供集中式批量压缩队列。
///
/// 设计意图：先用现有本地压缩能力建立可暂停、继续、取消和失败重试的队列
/// 骨架；后续裁剪、旋转、格式转换等批量任务可沿用同一状态模型扩展。
/// 异常策略：单个任务失败不会中断队列，错误写入历史并展示在任务行内。
class BatchController extends GetxController {
  BatchController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required AppSettingsRepository settingsRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _settingsRepository = settingsRepository,
       _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final AppSettingsRepository _settingsRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <BatchCompressionTask>[].obs;
  final quality = 80.obs;
  final processedCount = 0.obs;
  final isRunning = false.obs;
  final isPaused = false.obs;
  final isCancelRequested = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDefaultQuality();
  }

  Future<void> _loadDefaultQuality() async {
    try {
      quality.value = await _settingsRepository.getDefaultQuality();
    } catch (_) {
      quality.value = 80;
    }
  }

  Future<void> pickImages() async {
    if (isRunning.value) {
      return;
    }
    try {
      final images = await _imageChannel.pickMultipleImages();
      if (images.isEmpty) {
        return;
      }
      selectedImages.assignAll(images);
      tasks.assignAll(
        images.map((image) => BatchCompressionTask(source: image)),
      );
      processedCount.value = 0;
      isPaused.value = false;
      isCancelRequested.value = false;
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  void updateQuality(double value) {
    if (isRunning.value) {
      return;
    }
    quality.value = value.round().clamp(1, 100);
  }

  Future<void> startQueue() async {
    if (isRunning.value) {
      return;
    }
    if (selectedImages.isEmpty) {
      _showError('请先选择图片');
      return;
    }
    tasks.assignAll(
      selectedImages.map((image) => BatchCompressionTask(source: image)),
    );
    processedCount.value = 0;
    isPaused.value = false;
    isCancelRequested.value = false;
    await _runQueue(onlyRetryFailed: false);
  }

  void pauseQueue() {
    if (!isRunning.value) {
      return;
    }
    isPaused.value = true;
    _markPendingAsPaused();
  }

  Future<void> resumeQueue() async {
    if (isRunning.value) {
      isPaused.value = false;
      _restorePausedToPending();
      return;
    }
    if (!tasks.any((task) => task.status == BatchTaskStatus.paused)) {
      return;
    }
    isPaused.value = false;
    isCancelRequested.value = false;
    _restorePausedToPending();
    await _runQueue(onlyRetryFailed: false);
  }

  void cancelQueue() {
    if (!isRunning.value && tasks.isEmpty) {
      return;
    }
    isCancelRequested.value = true;
    isPaused.value = false;
    for (var index = 0; index < tasks.length; index++) {
      final status = tasks[index].status;
      if (status == BatchTaskStatus.pending ||
          status == BatchTaskStatus.paused) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.canceled);
      }
    }
  }

  Future<void> retryFailed() async {
    if (isRunning.value) {
      return;
    }
    if (!tasks.any((task) => task.canRetry)) {
      _showError('暂无失败任务可重试');
      return;
    }
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].canRetry) {
        tasks[index] = tasks[index].copyWith(
          status: BatchTaskStatus.pending,
          clearError: true,
        );
      }
    }
    isPaused.value = false;
    isCancelRequested.value = false;
    await _runQueue(onlyRetryFailed: true);
  }

  Future<void> _runQueue({required bool onlyRetryFailed}) async {
    isRunning.value = true;
    try {
      for (var index = 0; index < tasks.length; index++) {
        if (isCancelRequested.value) {
          _markPendingAsCanceled();
          break;
        }
        if (isPaused.value) {
          _markPendingAsPaused();
          break;
        }
        if (tasks[index].status != BatchTaskStatus.pending) {
          continue;
        }
        await _processTask(index);
      }
      _showCompletionSnack(onlyRetryFailed: onlyRetryFailed);
    } finally {
      isRunning.value = false;
    }
  }

  Future<void> _processTask(int index) async {
    final task = tasks[index];
    tasks[index] = task.copyWith(
      status: BatchTaskStatus.running,
      clearError: true,
    );
    try {
      final compressed = await _imageChannel.compressImage(
        source: task.source,
        quality: quality.value,
      );
      tasks[index] = tasks[index].copyWith(
        result: compressed,
        status: BatchTaskStatus.success,
        clearError: true,
      );
      await _historyRepository.recordCompressionSuccess(
        inputPath: task.source.path,
        outputPath: compressed.outputPath,
        quality: quality.value,
      );
    } on AppException catch (error) {
      tasks[index] = tasks[index].copyWith(
        status: BatchTaskStatus.failed,
        errorMessage: error.message,
      );
      await _historyRepository.recordCompressionFailure(
        inputPath: task.source.path,
        quality: quality.value,
        errorMessage: error.message,
      );
    } finally {
      processedCount.value = tasks.where((task) => task.isTerminal).length;
    }
  }

  void _markPendingAsPaused() {
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].status == BatchTaskStatus.pending) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.paused);
      }
    }
  }

  void _restorePausedToPending() {
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].status == BatchTaskStatus.paused) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.pending);
      }
    }
  }

  void _markPendingAsCanceled() {
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].status == BatchTaskStatus.pending ||
          tasks[index].status == BatchTaskStatus.paused) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.canceled);
      }
    }
  }

  void _showCompletionSnack({required bool onlyRetryFailed}) {
    if (tasks.isEmpty || isPaused.value) {
      return;
    }
    final success = successCount;
    final failed = failedCount;
    final canceled = canceledCount;
    final title = onlyRetryFailed ? '失败重试完成' : '批量队列完成';
    Get.snackbar(title, '成功 $success 张，失败 $failed 张，取消 $canceled 张');
  }

  double get progress {
    if (tasks.isEmpty) {
      return 0;
    }
    return processedCount.value / tasks.length;
  }

  int get successCount =>
      tasks.where((task) => task.status == BatchTaskStatus.success).length;

  int get failedCount =>
      tasks.where((task) => task.status == BatchTaskStatus.failed).length;

  int get canceledCount =>
      tasks.where((task) => task.status == BatchTaskStatus.canceled).length;

  int get pausedCount =>
      tasks.where((task) => task.status == BatchTaskStatus.paused).length;

  int get totalSizeBytes =>
      selectedImages.fold<int>(0, (sum, image) => sum + image.sizeBytes);

  String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '未知大小';
    }
    const unit = 1024;
    if (bytes < unit) {
      return '$bytes B';
    }
    final kib = bytes / unit;
    if (kib < unit) {
      return '${kib.toStringAsFixed(1)} KB';
    }
    final mib = kib / unit;
    return '${mib.toStringAsFixed(1)} MB';
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
