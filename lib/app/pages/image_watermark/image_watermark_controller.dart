import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/image_watermarked_file.dart';
import '../../core/models/local_image_file.dart';
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
  topLeft(label: '左上', value: 'topLeft'),
  topRight(label: '右上', value: 'topRight'),
  bottomLeft(label: '左下', value: 'bottomLeft'),
  bottomRight(label: '右下', value: 'bottomRight'),
  center(label: '居中', value: 'center'),
  tile(label: '平铺', value: 'tile');

  const ImageWatermarkPosition({required this.label, required this.value});

  final String label;
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
      _showError('记录最近文件失败，请重试');
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
      _showError('请先选择底图');
      return;
    }
    if (watermark == null) {
      _showError('请先选择水印图片');
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
            rotationDegrees: rotationDegrees.value,
          );
          result.value = watermarked;
          tasks[index] = tasks[index].copyWith(
            result: watermarked,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: '图片水印',
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
            featureName: '图片水印',
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
        Get.snackbar('图片水印完成', '已成功处理 $successCount 张图片');
      } else {
        Get.snackbar(
          '批量图片水印完成',
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

  Map<String, Object> _historyParameters(LocalImageFile watermark) {
    return <String, Object>{
      'watermarkPath': watermark.path,
      'position': position.value.value,
      'opacity': opacity.value,
      'scalePercent': scalePercent.value,
      'rotationDegrees': rotationDegrees.value,
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
      _showError('记录最近文件失败，请重试');
    }
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}

typedef ValueChangedLocalImage = void Function(LocalImageFile image);
