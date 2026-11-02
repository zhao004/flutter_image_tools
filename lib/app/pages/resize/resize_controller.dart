import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/local_image_file.dart';
import '../../models/resized_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class ResizeTask {
  const ResizeTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final ResizedImageFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  ResizeTask copyWith({
    ResizedImageFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return ResizeTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// 图片尺寸调整控制器，管理选图、目标宽高、比例锁定和缩放结果。
///
/// 异常策略：所有用户输入先在 Dart 侧校验，避免无效尺寸进入原生层；原生
/// 导出失败时记录失败历史，便于用户后续定位源文件和参数；批量保持比例时
/// 按百分比逐图缩放，避免不同宽高比图片被强行拉伸。
class ResizeController extends GetxController {
  ResizeController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  static const int minDimension = 1;
  static const int maxDimension = LocalImageChannel.maxResizeDimension;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<ResizedImageFile>();
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <ResizeTask>[].obs;
  final processedCount = 0.obs;
  final keepAspectRatio = true.obs;
  final percent = 100.0.obs;
  final isBusy = false.obs;
  final widthController = TextEditingController();
  final heightController = TextEditingController();

  @override
  void onClose() {
    widthController.dispose();
    heightController.dispose();
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
      _applyImageDimensions(image);
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('resize.error.recentFileFailed'.tr);
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
      tasks.assignAll(images.map((image) => ResizeTask(source: image)));
      _applyImageDimensions(images.first);
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('resize.error.recentFileFailed'.tr);
    }
  }

  void updateKeepAspectRatio(bool value) {
    keepAspectRatio.value = value;
  }

  void updateWidth(String value) {
    if (!keepAspectRatio.value) {
      return;
    }
    final image = selectedImage.value;
    final width = int.tryParse(value.trim());
    if (image == null || !image.hasValidDimensions || width == null) {
      return;
    }
    final nextHeight = _scaledCompanion(
      changed: width,
      sourceChanged: image.width,
      sourceCompanion: image.height,
    );
    heightController.text = nextHeight.toString();
    _updatePercentFromWidth(width, image);
  }

  void updateHeight(String value) {
    if (!keepAspectRatio.value) {
      return;
    }
    final image = selectedImage.value;
    final height = int.tryParse(value.trim());
    if (image == null || !image.hasValidDimensions || height == null) {
      return;
    }
    final nextWidth = _scaledCompanion(
      changed: height,
      sourceChanged: image.height,
      sourceCompanion: image.width,
    );
    widthController.text = nextWidth.toString();
    _updatePercentFromHeight(height, image);
  }

  void updatePercent(double value) {
    final image = selectedImage.value;
    if (image == null || !image.hasValidDimensions) {
      _showError('resize.error.missingDimensions'.tr);
      return;
    }
    percent.value = value;
    final nextWidth = _scaleDimension(image.width, value);
    final nextHeight = _scaleDimension(image.height, value);
    widthController.text = nextWidth.toString();
    heightController.text = nextHeight.toString();
  }

  Future<void> resize() async {
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
      _showError('resize.error.pickImageFirst'.tr);
      return;
    }
    final baseDimensions = _readDimensions();
    if (baseDimensions == null) {
      return;
    }

    isBusy.value = true;
    processedCount.value = 0;
    tasks.assignAll(selectedImages.map((image) => ResizeTask(source: image)));
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
        final dimensions = _dimensionsForSource(source, baseDimensions);
        try {
          final resized = await _imageChannel.resizeImage(
            source: source,
            width: dimensions.width,
            height: dimensions.height,
          );
          result.value = resized;
          tasks[index] = tasks[index].copyWith(
            result: resized,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: 'resize.featureName'.tr,
            inputPath: source.path,
            outputPath: resized.outputPath,
            parameters: _historyParameters(dimensions),
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: 'resize.featureName'.tr,
            inputPath: source.path,
            parameters: _historyParameters(dimensions),
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        showLatestSnackbar(
          'resize.success.title'.tr,
          'resize.success.message'.trParams({'count': successCount.toString()}),
        );
      } else {
        showLatestSnackbar(
          'resize.batch.success.title'.tr,
          'resize.batch.success.message'.trParams({
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

  String formatDimensions(LocalImageFile image) {
    if (!image.hasValidDimensions) {
      return 'resize.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  void _applyImageDimensions(LocalImageFile image) {
    if (!image.hasValidDimensions) {
      widthController.clear();
      heightController.clear();
      percent.value = 100;
      return;
    }
    widthController.text = image.width.toString();
    heightController.text = image.height.toString();
    percent.value = 100;
  }

  _ResizeDimensions? _readDimensions() {
    final width = int.tryParse(widthController.text.trim());
    final height = int.tryParse(heightController.text.trim());
    if (width == null || height == null) {
      _showError('resize.error.invalidDimensions'.tr);
      return null;
    }
    if (width < minDimension || height < minDimension) {
      _showError('resize.error.nonPositiveDimensions'.tr);
      return null;
    }
    if (width > maxDimension || height > maxDimension) {
      _showError(
        'resize.error.dimensionsTooLarge'.trParams({
          'max': maxDimension.toString(),
        }),
      );
      return null;
    }
    return _ResizeDimensions(width: width, height: height);
  }

  _ResizeDimensions _dimensionsForSource(
    LocalImageFile source,
    _ResizeDimensions fallback,
  ) {
    if (selectedImages.length <= 1 ||
        !keepAspectRatio.value ||
        !source.hasValidDimensions) {
      return fallback;
    }
    return _ResizeDimensions(
      width: _scaleDimension(source.width, percent.value),
      height: _scaleDimension(source.height, percent.value),
    );
  }

  Map<String, Object> _historyParameters(_ResizeDimensions dimensions) {
    return <String, Object>{
      'width': dimensions.width,
      'height': dimensions.height,
      'keepAspectRatio': keepAspectRatio.value,
      'percent': percent.value.round(),
    };
  }

  int _scaledCompanion({
    required int changed,
    required int sourceChanged,
    required int sourceCompanion,
  }) {
    if (changed <= 0 || sourceChanged <= 0 || sourceCompanion <= 0) {
      return minDimension;
    }
    return (changed * sourceCompanion / sourceChanged).round().clamp(
      minDimension,
      maxDimension,
    );
  }

  int _scaleDimension(int value, double scalePercent) {
    return (value * scalePercent / 100).round().clamp(
      minDimension,
      maxDimension,
    );
  }

  void _updatePercentFromWidth(int width, LocalImageFile image) {
    if (image.width <= 0 || width <= 0) {
      return;
    }
    percent.value = (width / image.width * 100).clamp(10, 300);
  }

  void _updatePercentFromHeight(int height, LocalImageFile image) {
    if (image.height <= 0 || height <= 0) {
      return;
    }
    percent.value = (height / image.height * 100).clamp(10, 300);
  }

  void _showError(String message) {
    showLatestSnackbar('resize.error.title'.tr, message);
  }
}

class _ResizeDimensions {
  const _ResizeDimensions({required this.width, required this.height});

  final int width;
  final int height;
}
