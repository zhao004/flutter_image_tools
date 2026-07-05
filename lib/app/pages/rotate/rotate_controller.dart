import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/rotated_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class RotationTask {
  const RotationTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final RotatedImageFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  RotationTask copyWith({
    RotatedImageFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return RotationTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// 图片旋转控制器，管理选图、角度设置、执行状态和旋转结果。
///
/// 异常策略：用户可恢复异常通过 Snackbar 提示；旋转失败写入历史记录，
/// 方便用户在历史页筛选失败任务并定位输入文件；批量旋转顺序执行，避免
/// 同时解码多张大图造成内存峰值过高。
class RotateController extends GetxController {
  RotateController({
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
  final result = Rxn<RotatedImageFile>();
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <RotationTask>[].obs;
  final processedCount = 0.obs;
  final degrees = 90.obs;
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
      tasks.assignAll(images.map((image) => RotationTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  void setDegrees(int value) {
    degrees.value = value.clamp(-360, 360);
  }

  void updateCustomDegrees(double value) {
    degrees.value = value.round().clamp(-180, 180);
  }

  Future<void> rotate() async {
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
    if (degrees.value == 0) {
      _showError('旋转角度不能为 0');
      return;
    }

    isBusy.value = true;
    processedCount.value = 0;
    tasks.assignAll(selectedImages.map((image) => RotationTask(source: image)));
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
        try {
          final rotated = await _imageChannel.rotateImage(
            source: source,
            degrees: degrees.value,
          );
          result.value = rotated;
          tasks[index] = tasks[index].copyWith(
            result: rotated,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: '图片旋转',
            inputPath: source.path,
            outputPath: rotated.outputPath,
            parameters: <String, Object>{'degrees': degrees.value},
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: '图片旋转',
            inputPath: source.path,
            parameters: <String, Object>{'degrees': degrees.value},
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        Get.snackbar('旋转完成', '已成功旋转 $successCount 张图片');
      } else {
        Get.snackbar(
          '批量旋转完成',
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
