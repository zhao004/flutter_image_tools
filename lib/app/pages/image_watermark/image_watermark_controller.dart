import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/image_watermarked_file.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class ImageWatermarkTask {
  const ImageWatermarkTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final ImageWatermarkedFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  ImageWatermarkTask copyWith({
    ImageWatermarkedFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return ImageWatermarkTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

enum ImageWatermarkPosition {
  topLeft(labelKey: 'imageWatermark.position.topLeft', value: 'topLeft'),
  topRight(labelKey: 'imageWatermark.position.topRight', value: 'topRight'),
  bottomLeft(
    labelKey: 'imageWatermark.position.bottomLeft',
    value: 'bottomLeft',
  ),
  bottomRight(
    labelKey: 'imageWatermark.position.bottomRight',
    value: 'bottomRight',
  ),
  center(labelKey: 'imageWatermark.position.center', value: 'center'),
  tile(labelKey: 'imageWatermark.position.tile', value: 'tile');

  const ImageWatermarkPosition({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

/// 图片水印控制器，管理底图、水印图、位置、透明度、缩放和旋转。
///
/// 异常策略：双图选择分别记录最近文件，参数在 Dart 侧做范围校验，原生端
/// 负责合成和导出；失败写入历史，方便追踪具体水印配置；批量水印顺序执行，
/// 避免多张大图同时合成导致内存峰值过高。
class ImageWatermarkController extends GetxController {
  ImageWatermarkController({
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
  final selectedWatermark = Rxn<LocalImageFile>();
  final result = Rxn<ImageWatermarkedFile>();
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <ImageWatermarkTask>[].obs;
  final processedCount = 0.obs;
  final position = ImageWatermarkPosition.bottomRight.obs;
  final opacity = 70.obs;
  final scalePercent = 25.obs;
  final spacing = 56.obs;
  final rotationDegrees = 0.obs;
  final isBusy = false.obs;

  Future<void> pickSourceImage() async {
    await _pickImage((image) {
      selectedImage.value = image;
      selectedImages.assignAll([image]);
      tasks.clear();
      processedCount.value = 0;
    });
  }

  Future<void> pickSourceImages() async {
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
      tasks.assignAll(images.map((image) => ImageWatermarkTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('imageWatermark.error.recentFileFailed'.tr);
    }
  }

  Future<void> pickWatermarkImage() async {
    await _pickImage((image) => selectedWatermark.value = image);
  }

  void setPosition(ImageWatermarkPosition value) {
    position.value = value;
  }

  void updateOpacity(double value) {
    opacity.value = value.round().clamp(10, 100);
  }

  void updateScale(double value) {
    scalePercent.value = value.round().clamp(5, 100);
  }

  void updateSpacing(double value) {
    spacing.value = value.round().clamp(8, 160);
  }

  void updateRotation(double value) {
    rotationDegrees.value = value.round().clamp(-180, 180);
  }

  Future<void> addWatermark() async {
    if (isBusy.value) {
      return;
    }
    if (selectedImages.isEmpty) {
      final source = selectedImage.value;
      if (source != null) {
        selectedImages.assignAll([source]);
      }
    }
    final watermark = selectedWatermark.value;
    if (selectedImages.isEmpty) {
      _showError('imageWatermark.error.pickSourceFirst'.tr);
      return;
    }
    if (watermark == null) {
      _showError('imageWatermark.error.pickWatermarkFirst'.tr);
      return;
    }

    isBusy.value = true;
    processedCount.value = 0;
    tasks.assignAll(
      selectedImages.map((image) => ImageWatermarkTask(source: image)),
    );
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
        try {
          final watermarked = await _imageChannel.addImageWatermark(
            source: source,
            watermark: watermark,
            position: position.value.value,
            opacity: opacity.value,
            scalePercent: scalePercent.value,
            spacing: spacing.value,
            rotationDegrees: rotationDegrees.value,
          );
          result.value = watermarked;
          tasks[index] = tasks[index].copyWith(
            result: watermarked,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: 'imageWatermark.featureName'.tr,
            inputPath: source.path,
            outputPath: watermarked.outputPath,
            parameters: _historyParameters(watermark),
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: 'imageWatermark.featureName'.tr,
            inputPath: source.path,
            parameters: _historyParameters(watermark),
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        showLatestSnackbar(
          'imageWatermark.success.title'.tr,
          'imageWatermark.success.message'.trParams({
            'count': successCount.toString(),
          }),
        );
      } else if (selectedImages.length == 1) {
        final errorMessage = tasks.first.errorMessage?.trim();
        _showError(
          errorMessage?.isNotEmpty == true
              ? errorMessage!
              : 'imageWatermark.error.exportFailed'.tr,
        );
      } else {
        showLatestSnackbar(
          'imageWatermark.batch.success.title'.tr,
          'imageWatermark.batch.success.message'.trParams({
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

  Map<String, Object> _historyParameters(LocalImageFile watermark) {
    return <String, Object>{
      'watermarkPath': watermark.path,
      'position': position.value.value,
      'opacity': opacity.value,
      'scalePercent': scalePercent.value,
      'spacing': spacing.value,
      'rotationDegrees': rotationDegrees.value,
    };
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
      return 'imageWatermark.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  String positionLabel(String value) {
    return ImageWatermarkPosition.values
        .firstWhere((item) => item.value == value, orElse: () => position.value)
        .labelKey
        .tr;
  }

  Future<void> _pickImage(ValueChangedLocalImage onSelected) async {
    if (isBusy.value) {
      return;
    }
    try {
      final image = await _imageChannel.pickSingleImage();
      if (image == null) {
        return;
      }
      onSelected(image);
      result.value = null;
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('imageWatermark.error.recentFileFailed'.tr);
    }
  }

  void _showError(String message) {
    showLatestSnackbar('imageWatermark.error.title'.tr, message);
  }
}

typedef ValueChangedLocalImage = void Function(LocalImageFile image);
