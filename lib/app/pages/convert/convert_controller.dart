import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/converted_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class ConvertTask {
  const ConvertTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final ConvertedImageFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  ConvertTask copyWith({
    ConvertedImageFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return ConvertTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

enum ConvertFormat {
  jpg(label: 'JPG', value: 'jpg'),
  png(label: 'PNG', value: 'png'),
  webp(label: 'WebP', value: 'webp'),
  bmp(label: 'BMP', value: 'bmp');

  const ConvertFormat({required this.label, required this.value});

  final String label;
  final String value;
}

/// 图片格式转换控制器，管理选图、目标格式、导出质量和转换结果。
///
/// 异常策略：格式和质量在发起原生调用前完成校验；转换失败写入历史记录，
/// 用户可以在历史页回看源文件、目标格式和错误原因；批量转换顺序执行，
/// 避免多张大图同时编码造成内存峰值过高。
class ConvertController extends GetxController {
  ConvertController({
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
  final result = Rxn<ConvertedImageFile>();
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <ConvertTask>[].obs;
  final processedCount = 0.obs;
  final format = ConvertFormat.jpg.obs;
  final quality = 95.obs;
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
      tasks.assignAll(images.map((image) => ConvertTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  void setFormat(ConvertFormat value) {
    format.value = value;
  }

  void updateQuality(double value) {
    quality.value = value.round().clamp(1, 100);
  }

  Future<void> convert() async {
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
    tasks.assignAll(selectedImages.map((image) => ConvertTask(source: image)));
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
        try {
          final converted = await _imageChannel.convertImage(
            source: source,
            format: format.value.value,
            quality: quality.value,
          );
          result.value = converted;
          tasks[index] = tasks[index].copyWith(
            result: converted,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: '格式转换',
            inputPath: source.path,
            outputPath: converted.outputPath,
            parameters: _historyParameters,
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: '格式转换',
            inputPath: source.path,
            parameters: _historyParameters,
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        Get.snackbar('格式转换完成', '已成功转换 $successCount 张图片');
      } else {
        Get.snackbar(
          '批量格式转换完成',
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

  Map<String, Object> get _historyParameters {
    return <String, Object>{
      'format': format.value.value,
      'quality': quality.value,
    };
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

  String formatDimensions(LocalImageFile image) {
    if (!image.hasValidDimensions) {
      return '未知尺寸';
    }
    return '${image.width} × ${image.height} px';
  }

  String qualityHint() {
    return switch (format.value) {
      ConvertFormat.jpg || ConvertFormat.webp => 'JPG 和 WebP 会使用导出质量。',
      ConvertFormat.png || ConvertFormat.bmp => 'PNG 和 BMP 为无损导出，质量参数会被忽略。',
    };
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
