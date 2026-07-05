import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/flipped_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class FlipTask {
  const FlipTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final FlippedImageFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  FlipTask copyWith({
    FlippedImageFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return FlipTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

enum FlipDirection {
  horizontal(label: '水平翻转', value: 'horizontal'),
  vertical(label: '垂直翻转', value: 'vertical');

  const FlipDirection({required this.label, required this.value});

  final String label;
  final String value;
}

/// 图片翻转控制器，管理选图、翻转方向、执行状态和结果展示。
///
/// 异常策略：平台和文件异常统一转为中文提示；失败任务写入历史记录，便于
/// 用户后续在历史页通过状态筛选定位问题；批量翻转顺序执行，降低多张大图
/// 同时处理导致的内存压力。
class FlipController extends GetxController {
  FlipController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<FlippedImageFile>();
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <FlipTask>[].obs;
  final processedCount = 0.obs;
  final direction = FlipDirection.horizontal.obs;
  final isBusy = false.obs;

  Future<void> pickImage() async {
    if (isBusy.value) {
      return;
    }
    try {
      final image = await _imageChannel.pickSingleImage();
      if (image == null) {
        return;
      }
      selectedImage.value = image;
      selectedImages.assignAll([image]);
      result.value = null;
      tasks.clear();
      processedCount.value = 0;
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  Future<void> pickImages() async {
    if (isBusy.value) {
      return;
    }
    try {
      final images = await _imageChannel.pickMultipleImages();
      if (images.isEmpty) {
        return;
      }
      selectedImages.assignAll(images);
      selectedImage.value = images.first;
      result.value = null;
      processedCount.value = 0;
      tasks.assignAll(images.map((image) => FlipTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  void setDirection(FlipDirection value) {
    direction.value = value;
  }

  Future<void> flip() async {
    if (isBusy.value) {
      return;
    }
    if (selectedImages.isEmpty) {
      final source = selectedImage.value;
      if (source != null) {
        selectedImages.assignAll([source]);
      }
    }
    if (selectedImages.isEmpty) {
      _showError('请先选择图片');
      return;
    }

    isBusy.value = true;
    processedCount.value = 0;
    tasks.assignAll(selectedImages.map((image) => FlipTask(source: image)));
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
        try {
          final flipped = await _imageChannel.flipImage(
            source: source,
            direction: direction.value.value,
          );
          result.value = flipped;
          tasks[index] = tasks[index].copyWith(
            result: flipped,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: '图片翻转',
            inputPath: source.path,
            outputPath: flipped.outputPath,
            parameters: <String, Object>{'direction': direction.value.value},
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: '图片翻转',
            inputPath: source.path,
            parameters: <String, Object>{'direction': direction.value.value},
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        Get.snackbar('翻转完成', '已成功翻转 $successCount 张图片');
      } else {
        Get.snackbar(
          '批量翻转完成',
          '成功 $successCount 张，失败 ${selectedImages.length - successCount} 张',
        );
      }
    } finally {
      isBusy.value = false;
    }
  }

  double get progress {
    final total = selectedImages.length;
    if (total <= 0) {
      return 0;
    }
    return processedCount.value / total;
  }

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
