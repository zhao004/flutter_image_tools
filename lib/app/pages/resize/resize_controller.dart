import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/resized_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// 图片尺寸调整控制器，管理选图、目标宽高、比例锁定和缩放结果。
///
/// 异常策略：所有用户输入先在 Dart 侧校验，避免无效尺寸进入原生层；原生
/// 导出失败时记录失败历史，便于用户后续定位源文件和参数。
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
      result.value = null;
      _applyImageDimensions(image);
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
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
      _showError('当前图片缺少原始尺寸，无法按百分比缩放');
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
    final source = selectedImage.value;
    if (source == null) {
      _showError('请先选择一张图片');
      return;
    }
    final dimensions = _readDimensions();
    if (dimensions == null) {
      return;
    }

    isBusy.value = true;
    try {
      final resized = await _imageChannel.resizeImage(
        source: source,
        width: dimensions.width,
        height: dimensions.height,
      );
      result.value = resized;
      await _historyRepository.recordOperationSuccess(
        featureName: '尺寸调整',
        inputPath: source.path,
        outputPath: resized.outputPath,
        parameters: <String, Object>{
          'width': dimensions.width,
          'height': dimensions.height,
          'keepAspectRatio': keepAspectRatio.value,
          'percent': percent.value.round(),
        },
      );
      Get.snackbar('尺寸调整完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '尺寸调整',
        inputPath: source.path,
        parameters: <String, Object>{
          'width': dimensions.width,
          'height': dimensions.height,
          'keepAspectRatio': keepAspectRatio.value,
          'percent': percent.value.round(),
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
      _showError('请输入有效的目标宽高');
      return null;
    }
    if (width < minDimension || height < minDimension) {
      _showError('目标宽高必须大于 0');
      return null;
    }
    if (width > maxDimension || height > maxDimension) {
      _showError('目标宽高不能超过 $maxDimension 像素');
      return null;
    }
    return _ResizeDimensions(width: width, height: height);
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
    Get.snackbar('操作失败', message);
  }
}

class _ResizeDimensions {
  const _ResizeDimensions({required this.width, required this.height});

  final int width;
  final int height;
}
