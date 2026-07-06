import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/cropped_image_file.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// 裁剪框在图片坐标中的归一化位置和尺寸。
///
/// 设计意图：UI 预览和导出服务都使用 0~1 比例描述裁剪区域，避免预览
/// 尺寸和原图像素尺寸不同导致导出偏移。边界由控制器和服务双层限制。
class CropFrameRatios {
  const CropFrameRatios({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

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
  square(labelKey: 'crop.preset.square', ratioText: '1:1', aspectRatio: 1),
  landscape16x9(
    labelKey: 'crop.preset.landscape16x9',
    ratioText: '16:9',
    aspectRatio: 16 / 9,
  ),
  landscape4x3(
    labelKey: 'crop.preset.landscape4x3',
    ratioText: '4:3',
    aspectRatio: 4 / 3,
  ),
  portrait9x16(
    labelKey: 'crop.preset.portrait9x16',
    ratioText: '9:16',
    aspectRatio: 9 / 16,
  ),
  custom(
    labelKey: 'crop.preset.custom',
    ratioText: 'crop.preset.customRatio',
    aspectRatio: 1,
  );

  const CropPreset({
    required this.labelKey,
    required this.ratioText,
    required this.aspectRatio,
  });

  final String labelKey;
  final String ratioText;
  final double aspectRatio;
}

/// 图片裁剪控制器，管理选图、比例预设、裁剪框位置和裁剪结果。
///
/// 异常策略：裁剪框位置使用归一化中心点保存，导出前再按每张原图尺寸
/// 计算像素区域；自定义比例在 Dart 侧限制范围，避免无效或极端比例触发
/// 图片解码异常；批量裁剪顺序执行，降低多张大图同时处理导致的内存峰值。
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
  final cropCenterXRatio = 0.5.obs;
  final cropCenterYRatio = 0.5.obs;
  final isDraggingCropFrame = false.obs;
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
      resetCropFrame();
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('crop.error.recentFileFailed'.tr);
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
      resetCropFrame();
      tasks.assignAll(images.map((image) => CropTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('crop.error.recentFileFailed'.tr);
    }
  }

  void setPreset(CropPreset value) {
    preset.value = value;
    resetCropFrame();
  }

  void resetCropFrame() {
    cropCenterXRatio.value = 0.5;
    cropCenterYRatio.value = 0.5;
  }

  void setCropFrameDragging(bool value) {
    if (isDraggingCropFrame.value == value) {
      return;
    }
    isDraggingCropFrame.value = value;
  }

  void updateCropFrame({
    required double centerXRatio,
    required double centerYRatio,
    required double frameWidthRatio,
    required double frameHeightRatio,
  }) {
    if (!centerXRatio.isFinite ||
        !centerYRatio.isFinite ||
        !frameWidthRatio.isFinite ||
        !frameHeightRatio.isFinite) {
      return;
    }
    final halfWidth = frameWidthRatio.clamp(0.0, 1.0) / 2;
    final halfHeight = frameHeightRatio.clamp(0.0, 1.0) / 2;
    cropCenterXRatio.value = centerXRatio.clamp(halfWidth, 1 - halfWidth);
    cropCenterYRatio.value = centerYRatio.clamp(halfHeight, 1 - halfHeight);
  }

  CropFrameRatios frameRatiosForImage(
    LocalImageFile image,
    double aspectRatio,
  ) {
    if (!image.hasValidDimensions ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0) {
      return const CropFrameRatios(left: 0, top: 0, width: 1, height: 1);
    }
    final sourceRatio = image.width / image.height;
    var widthRatio = 1.0;
    var heightRatio = 1.0;
    if (sourceRatio > aspectRatio) {
      widthRatio = (image.height * aspectRatio / image.width).clamp(0.0, 1.0);
    } else {
      heightRatio = (image.width / aspectRatio / image.height).clamp(0.0, 1.0);
    }

    final halfWidth = widthRatio / 2;
    final halfHeight = heightRatio / 2;
    final centerX = cropCenterXRatio.value.clamp(halfWidth, 1 - halfWidth);
    final centerY = cropCenterYRatio.value.clamp(halfHeight, 1 - halfHeight);
    return CropFrameRatios(
      left: (centerX - halfWidth).clamp(0.0, 1 - widthRatio),
      top: (centerY - halfHeight).clamp(0.0, 1 - heightRatio),
      width: widthRatio,
      height: heightRatio,
    );
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
      _showError('crop.error.pickImageFirst'.tr);
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
        final cropFrame = frameRatiosForImage(source, aspectRatio);
        try {
          final cropped = await _imageChannel.cropImage(
            source: source,
            aspectRatio: aspectRatio,
            cropLeftRatio: cropFrame.left,
            cropTopRatio: cropFrame.top,
          );
          result.value = cropped;
          tasks[index] = tasks[index].copyWith(
            result: cropped,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: 'crop.featureName'.tr,
            inputPath: source.path,
            outputPath: cropped.outputPath,
            parameters: _historyParameters(aspectRatio, cropFrame),
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: 'crop.featureName'.tr,
            inputPath: source.path,
            parameters: _historyParameters(aspectRatio, cropFrame),
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        showLatestSnackbar(
          'crop.success.title'.tr,
          'crop.success.message'.trParams({'count': successCount.toString()}),
        );
      } else {
        showLatestSnackbar(
          'crop.batch.success.title'.tr,
          'crop.batch.success.message'.trParams({
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
      return 'crop.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  String currentRatioText() {
    final currentPreset = preset.value;
    if (currentPreset != CropPreset.custom) {
      return currentPreset.ratioText.tr;
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
      _showError('crop.error.invalidCustomRatio'.tr);
      return null;
    }
    if (width <= 0 || height <= 0) {
      _showError('crop.error.nonPositiveCustomRatio'.tr);
      return null;
    }
    final ratio = width / height;
    if (ratio < 0.1 || ratio > 10) {
      _showError('crop.error.customRatioOutOfRange'.tr);
      return null;
    }
    return ratio;
  }

  Map<String, Object> _historyParameters(
    double aspectRatio,
    CropFrameRatios cropFrame,
  ) {
    return <String, Object>{
      'preset': preset.value.name,
      'aspectRatio': aspectRatio,
      'cropLeftRatio': cropFrame.left,
      'cropTopRatio': cropFrame.top,
      'cropWidthRatio': cropFrame.width,
      'cropHeightRatio': cropFrame.height,
    };
  }

  void _showError(String message) {
    showLatestSnackbar('crop.error.title'.tr, message);
  }
}
