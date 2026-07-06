import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/compressed_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class CompressionTask {
  const CompressionTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final CompressedImageFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  CompressionTask copyWith({
    CompressedImageFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return CompressionTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// 图片压缩控制器，管理选择、质量参数、执行状态和结果展示。
///
/// 异常策略：所有用户可恢复错误显示 Snackbar，并在已有输入文件时写入失败
/// 历史；未知错误由服务层包装，避免界面层直接处理平台异常。
class CompressController extends GetxController {
  CompressController({
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

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<CompressedImageFile>();
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <CompressionTask>[].obs;
  final processedCount = 0.obs;
  final quality = 80.obs;
  final isBusy = false.obs;

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
      tasks.clear();
      processedCount.value = 0;
      result.value = null;
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('compress.error.recentFileFailed'.tr);
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
      tasks.assignAll(images.map((image) => CompressionTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('compress.error.recentFileFailed'.tr);
    }
  }

  void updateQuality(double value) {
    quality.value = value.round().clamp(1, 100);
  }

  Future<void> compress() async {
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
      _showError('compress.error.pickImageFirst'.tr);
      return;
    }

    isBusy.value = true;
    processedCount.value = 0;
    tasks.assignAll(
      selectedImages.map((image) => CompressionTask(source: image)),
    );
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
        try {
          final compressed = await _imageChannel.compressImage(
            source: source,
            quality: quality.value,
          );
          result.value = compressed;
          tasks[index] = tasks[index].copyWith(
            result: compressed,
            isCompleted: true,
          );
          await _historyRepository.recordCompressionSuccess(
            inputPath: source.path,
            outputPath: compressed.outputPath,
            quality: quality.value,
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordCompressionFailure(
            inputPath: source.path,
            quality: quality.value,
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        Get.snackbar(
          'compress.success.title'.tr,
          'compress.success.message'.trParams({
            'count': successCount.toString(),
          }),
        );
      } else {
        Get.snackbar(
          'compress.batch.success.title'.tr,
          'compress.batch.success.message'.trParams({
            'success': successCount.toString(),
            'failed': (selectedImages.length - successCount).toString(),
          }),
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
      return 'common.unknownSize'.tr;
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
    Get.snackbar('compress.error.title'.tr, message);
  }
}
