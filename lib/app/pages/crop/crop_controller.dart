import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/cropped_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class CropTask {
  const CropTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final CroppedImageFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  CropTask copyWith({
    CroppedImageFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return CropTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

enum CropPreset {
  square(label: '正方形', ratioText: '1:1', aspectRatio: 1),
  landscape16x9(label: '横版', ratioText: '16:9', aspectRatio: 16 / 9),
  landscape4x3(label: '经典', ratioText: '4:3', aspectRatio: 4 / 3),
  portrait9x16(label: '竖版', ratioText: '9:16', aspectRatio: 9 / 16),
  custom(label: '自定义', ratioText: '自定义', aspectRatio: 1);

  const CropPreset({
    required this.label,
    required this.ratioText,
    required this.aspectRatio,
  });

  final String label;
  final String ratioText;
  final double aspectRatio;
}

/// 图片裁剪控制器，管理选图、比例预设、自定义比例和裁剪结果。
///
/// 异常策略：当前阶段采用居中裁剪，先保证常用比例稳定导出；自定义比例
/// 在 Dart 侧限制范围，避免无效或极端比例触发原生 Bitmap 异常；批量裁剪
/// 顺序执行，降低多张大图同时处理导致的内存峰值。
class CropController extends GetxController {
  CropController({
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
  final result = Rxn<CroppedImageFile>();
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <CropTask>[].obs;
  final processedCount = 0.obs;
  final preset = CropPreset.square.obs;
  final isBusy = false.obs;
  final customWidthController = TextEditingController(text: '1');
  final customHeightController = TextEditingController(text: '1');

  @override
  void onClose() {
    customWidthController.dispose();
    customHeightController.dispose();
    super.onClose();
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
      tasks.assignAll(images.map((image) => CropTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  void setPreset(CropPreset value) {
    preset.value = value;
  }

  Future<void> crop() async {
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
    final aspectRatio = _readAspectRatio();
    if (aspectRatio == null) {
      return;
    }

    isBusy.value = true;
    processedCount.value = 0;
    tasks.assignAll(selectedImages.map((image) => CropTask(source: image)));
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
        try {
          final cropped = await _imageChannel.cropImage(
            source: source,
            aspectRatio: aspectRatio,
          );
          result.value = cropped;
          tasks[index] = tasks[index].copyWith(
            result: cropped,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: '图片裁剪',
            inputPath: source.path,
            outputPath: cropped.outputPath,
            parameters: _historyParameters(aspectRatio),
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: '图片裁剪',
            inputPath: source.path,
            parameters: _historyParameters(aspectRatio),
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        Get.snackbar('裁剪完成', '已成功裁剪 $successCount 张图片');
      } else {
        Get.snackbar(
          '批量裁剪完成',
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

  String formatDimensions(LocalImageFile image) {
    if (!image.hasValidDimensions) {
      return '未知尺寸';
    }
    return '${image.width} × ${image.height} px';
  }

  String currentRatioText() {
    final currentPreset = preset.value;
    if (currentPreset != CropPreset.custom) {
      return currentPreset.ratioText;
    }
    final width = customWidthController.text.trim();
    final height = customHeightController.text.trim();
    return '$width:$height';
  }

  double? _readAspectRatio() {
    final currentPreset = preset.value;
    if (currentPreset != CropPreset.custom) {
      return currentPreset.aspectRatio;
    }
    final width = double.tryParse(customWidthController.text.trim());
    final height = double.tryParse(customHeightController.text.trim());
    if (width == null || height == null) {
      _showError('请输入有效的自定义比例');
      return null;
    }
    if (width <= 0 || height <= 0) {
      _showError('自定义比例必须大于 0');
      return null;
    }
    final ratio = width / height;
    if (ratio < 0.1 || ratio > 10) {
      _showError('自定义比例必须在 0.1 到 10 之间');
      return null;
    }
    return ratio;
  }

  Map<String, Object> _historyParameters(double aspectRatio) {
    return <String, Object>{
      'preset': preset.value.name,
      'aspectRatio': aspectRatio,
    };
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
