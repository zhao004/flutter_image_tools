import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/image_watermarked_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

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
/// 负责合成和导出；失败写入历史，方便追踪具体水印配置。
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
  final position = ImageWatermarkPosition.bottomRight.obs;
  final opacity = 70.obs;
  final scalePercent = 25.obs;
  final rotationDegrees = 0.obs;
  final isBusy = false.obs;

  Future<void> pickSourceImage() async {
    await _pickImage((image) => selectedImage.value = image);
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
    final source = selectedImage.value;
    final watermark = selectedWatermark.value;
    if (source == null) {
      _showError('请先选择底图');
      return;
    }
    if (watermark == null) {
      _showError('请先选择水印图片');
      return;
    }

    isBusy.value = true;
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
      await _historyRepository.recordOperationSuccess(
        featureName: '图片水印',
        inputPath: source.path,
        outputPath: watermarked.outputPath,
        parameters: <String, Object>{
          'watermarkPath': watermark.path,
          'position': position.value.value,
          'opacity': opacity.value,
          'scalePercent': scalePercent.value,
          'rotationDegrees': rotationDegrees.value,
        },
      );
      Get.snackbar('水印完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片水印',
        inputPath: source.path,
        parameters: <String, Object>{
          'watermarkPath': watermark.path,
          'position': position.value.value,
          'opacity': opacity.value,
          'scalePercent': scalePercent.value,
          'rotationDegrees': rotationDegrees.value,
        },
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
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
