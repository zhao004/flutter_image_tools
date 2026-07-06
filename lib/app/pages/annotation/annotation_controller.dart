import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/annotated_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum AnnotationMode {
  brush(labelKey: 'annotation.mode.brush', value: 'brush'),
  arrow(labelKey: 'annotation.mode.arrow', value: 'arrow'),
  rectangle(labelKey: 'annotation.mode.rectangle', value: 'rectangle'),
  circle(labelKey: 'annotation.mode.circle', value: 'circle'),
  text(labelKey: 'annotation.mode.text', value: 'text'),
  highlight(labelKey: 'annotation.mode.highlight', value: 'highlight'),
  mosaic(labelKey: 'annotation.mode.mosaic', value: 'mosaic');

  const AnnotationMode({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  String get label => labelKey.tr;
}

enum AnnotationColor {
  red(labelKey: 'annotation.color.red', value: '#E53935'),
  yellow(labelKey: 'annotation.color.yellow', value: '#FDD835'),
  blue(labelKey: 'annotation.color.blue', value: '#1E88E5'),
  green(labelKey: 'annotation.color.green', value: '#43A047'),
  white(labelKey: 'annotation.color.white', value: '#FFFFFF');

  const AnnotationColor({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  String get label => labelKey.tr;
}

/// 图片标注控制器，管理选图、标注模式、颜色、粗细、文本和导出结果。
///
/// 异常策略：标注模式、文本长度和线条粗细在 Dart 侧先校验，平台端再做
/// 文件与绘制校验；导出失败会写入历史记录，方便用户回溯参数。
class AnnotationController extends GetxController {
  AnnotationController({
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
  final result = Rxn<AnnotatedImageFile>();
  final mode = AnnotationMode.brush.obs;
  final color = AnnotationColor.red.obs;
  final strokeWidth = 12.obs;
  final isBusy = false.obs;
  final textController = TextEditingController();

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
      _showError('annotation.error.recentFileFailed'.tr);
    }
  }

  void setMode(AnnotationMode value) {
    mode.value = value;
  }

  void setColor(AnnotationColor value) {
    color.value = value;
  }

  void updateStrokeWidth(double value) {
    strokeWidth.value = value.round().clamp(2, 48);
  }

  Future<void> annotate() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }
    final text = textController.text.trim();
    if (mode.value == AnnotationMode.text && text.isEmpty) {
      _showError('annotation.error.textRequired'.tr);
      return;
    }
    if (text.length > 40) {
      _showError('annotation.error.textTooLong'.trParams({'max': '40'}));
      return;
    }

    isBusy.value = true;
    try {
      final annotated = await _imageChannel.annotateImage(
        source: source,
        mode: mode.value.value,
        text: text,
        color: color.value.value,
        strokeWidth: strokeWidth.value,
      );
      result.value = annotated;
      await _historyRepository.recordOperationSuccess(
        featureName: 'annotation.featureName'.tr,
        inputPath: source.path,
        outputPath: annotated.outputPath,
        parameters: _historyParameters(text),
      );
      Get.snackbar(
        'annotation.export.success.title'.tr,
        'annotation.export.success.message'.tr,
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'annotation.featureName'.tr,
        inputPath: source.path,
        parameters: _historyParameters(text),
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
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
      return 'annotation.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  String labelForModeValue(String value) {
    for (final mode in AnnotationMode.values) {
      if (mode.value == value) {
        return mode.label;
      }
    }
    return value;
  }

  Map<String, Object> _historyParameters(String text) {
    return <String, Object>{
      'mode': mode.value.value,
      'color': color.value.value,
      'strokeWidth': strokeWidth.value,
      if (text.isNotEmpty) 'text': text,
    };
  }

  void _showError(String message) {
    Get.snackbar('annotation.error.title'.tr, message);
  }
}
