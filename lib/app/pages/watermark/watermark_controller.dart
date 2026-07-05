import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/watermarked_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

class WatermarkTask {
  const WatermarkTask({
    required this.source,
    this.result,
    this.errorMessage,
    this.isCompleted = false,
  });

  final LocalImageFile source;
  final WatermarkedImageFile? result;
  final String? errorMessage;
  final bool isCompleted;

  bool get isSuccess => isCompleted && result != null;

  WatermarkTask copyWith({
    WatermarkedImageFile? result,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return WatermarkTask(
      source: source,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

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
/// 文件导出；失败任务写入历史记录，便于定位具体水印参数；批量水印顺序执行，
/// 避免多张大图同时绘制导致内存峰值过高。
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
  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <WatermarkTask>[].obs;
  final processedCount = 0.obs;
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
      tasks.assignAll(images.map((image) => WatermarkTask(source: image)));
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
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
    processedCount.value = 0;
    tasks.assignAll(
      selectedImages.map((image) => WatermarkTask(source: image)),
    );
    try {
      for (var index = 0; index < selectedImages.length; index++) {
        final source = selectedImages[index];
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
          tasks[index] = tasks[index].copyWith(
            result: watermarked,
            isCompleted: true,
          );
          await _historyRepository.recordOperationSuccess(
            featureName: '文字水印',
            inputPath: source.path,
            outputPath: watermarked.outputPath,
            parameters: _historyParameters(text),
          );
        } on AppException catch (error) {
          tasks[index] = tasks[index].copyWith(
            errorMessage: error.message,
            isCompleted: true,
          );
          await _historyRepository.recordOperationFailure(
            featureName: '文字水印',
            inputPath: source.path,
            parameters: _historyParameters(text),
            errorMessage: error.message,
          );
        } finally {
          processedCount.value = index + 1;
        }
      }
      final successCount = tasks.where((task) => task.isSuccess).length;
      if (successCount == selectedImages.length) {
        Get.snackbar('水印完成', '已成功添加 $successCount 张图片');
      } else {
        Get.snackbar(
          '批量水印完成',
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

  Map<String, Object> _historyParameters(String text) {
    return <String, Object>{
      'text': text,
      'position': position.value.value,
      'fontSize': fontSize.value,
      'opacity': opacity.value,
      'color': color.value.value,
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

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
