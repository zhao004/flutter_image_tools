import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/watermarked_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum WatermarkPosition {
  topLeft(label: '左上', value: 'topLeft'),
  topRight(label: '右上', value: 'topRight'),
  bottomLeft(label: '左下', value: 'bottomLeft'),
  bottomRight(label: '右下', value: 'bottomRight'),
  center(label: '居中', value: 'center'),
  tile(label: '平铺', value: 'tile');

  const WatermarkPosition({required this.label, required this.value});

  final String label;
  final String value;
}

enum WatermarkColor {
  white(label: '白色', value: '#FFFFFF'),
  black(label: '黑色', value: '#000000'),
  red(label: '红色', value: '#E53935'),
  yellow(label: '黄色', value: '#FDD835');

  const WatermarkColor({required this.label, required this.value});

  final String label;
  final String value;
}

/// 文字水印控制器，管理选图、水印文字、位置、颜色、字号和透明度。
///
/// 异常策略：文本长度、字号和透明度在 Dart 侧校验，原生端负责最终绘制和
/// 文件导出；失败任务写入历史记录，便于定位具体水印参数。
class WatermarkController extends GetxController {
  WatermarkController({
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
  final result = Rxn<WatermarkedImageFile>();
  final position = WatermarkPosition.bottomRight.obs;
  final color = WatermarkColor.white.obs;
  final fontSize = 36.obs;
  final opacity = 70.obs;
  final isBusy = false.obs;
  final textController = TextEditingController(text: 'Image Toolkit');

  @override
  void onClose() {
    textController.dispose();
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

  void setPosition(WatermarkPosition value) {
    position.value = value;
  }

  void setColor(WatermarkColor value) {
    color.value = value;
  }

  void updateFontSize(double value) {
    fontSize.value = value.round().clamp(12, 160);
  }

  void updateOpacity(double value) {
    opacity.value = value.round().clamp(10, 100);
  }

  Future<void> addWatermark() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('请先选择一张图片');
      return;
    }
    final text = textController.text.trim();
    if (text.isEmpty) {
      _showError('请输入水印文字');
      return;
    }
    if (text.length > 80) {
      _showError('水印文字不能超过 80 个字符');
      return;
    }

    isBusy.value = true;
    try {
      final watermarked = await _imageChannel.addTextWatermark(
        source: source,
        text: text,
        position: position.value.value,
        fontSize: fontSize.value,
        opacity: opacity.value,
        color: color.value.value,
      );
      result.value = watermarked;
      await _historyRepository.recordOperationSuccess(
        featureName: '文字水印',
        inputPath: source.path,
        outputPath: watermarked.outputPath,
        parameters: <String, Object>{
          'text': text,
          'position': position.value.value,
          'fontSize': fontSize.value,
          'opacity': opacity.value,
          'color': color.value.value,
        },
      );
      Get.snackbar('水印完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '文字水印',
        inputPath: source.path,
        parameters: <String, Object>{
          'text': text,
          'position': position.value.value,
          'fontSize': fontSize.value,
          'opacity': opacity.value,
          'color': color.value.value,
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

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
