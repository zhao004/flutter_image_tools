import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/cropped_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

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
/// 在 Dart 侧限制范围，避免无效或极端比例触发原生 Bitmap 异常。
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
      result.value = null;
      await _recentFilesRepository.recordImage(image);
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
    final source = selectedImage.value;
    if (source == null) {
      _showError('请先选择一张图片');
      return;
    }
    final aspectRatio = _readAspectRatio();
    if (aspectRatio == null) {
      return;
    }

    isBusy.value = true;
    try {
      final cropped = await _imageChannel.cropImage(
        source: source,
        aspectRatio: aspectRatio,
      );
      result.value = cropped;
      await _historyRepository.recordOperationSuccess(
        featureName: '图片裁剪',
        inputPath: source.path,
        outputPath: cropped.outputPath,
        parameters: <String, Object>{
          'preset': preset.value.name,
          'aspectRatio': aspectRatio,
        },
      );
      Get.snackbar('裁剪完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片裁剪',
        inputPath: source.path,
        parameters: <String, Object>{
          'preset': preset.value.name,
          'aspectRatio': aspectRatio,
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

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
