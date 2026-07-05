import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/annotated_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum AnnotationMode {
  brush(label: '画笔', value: 'brush'),
  arrow(label: '箭头', value: 'arrow'),
  rectangle(label: '矩形', value: 'rectangle'),
  circle(label: '圆形', value: 'circle'),
  text(label: '文本', value: 'text'),
  highlight(label: '高亮', value: 'highlight'),
  mosaic(label: '马赛克', value: 'mosaic');

  const AnnotationMode({required this.label, required this.value});

  final String label;
  final String value;
}

enum AnnotationColor {
  red(label: '红色', value: '#E53935'),
  yellow(label: '黄色', value: '#FDD835'),
  blue(label: '蓝色', value: '#1E88E5'),
  green(label: '绿色', value: '#43A047'),
  white(label: '白色', value: '#FFFFFF');

  const AnnotationColor({required this.label, required this.value});

  final String label;
  final String value;
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
  final textController = TextEditingController(text: '标注文本');

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
      _showError('请先选择一张图片');
      return;
    }
    final text = textController.text.trim();
    if (mode.value == AnnotationMode.text && text.isEmpty) {
      _showError('文本标注内容不能为空');
      return;
    }
    if (text.length > 40) {
      _showError('文本标注不能超过 40 个字符');
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
        featureName: '图片标注',
        inputPath: source.path,
        outputPath: annotated.outputPath,
        parameters: _historyParameters(text),
      );
      Get.snackbar('标注完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片标注',
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

  Map<String, Object> _historyParameters(String text) {
    return <String, Object>{
      'mode': mode.value.value,
      'color': color.value.value,
      'strokeWidth': strokeWidth.value,
      if (text.isNotEmpty) 'text': text,
    };
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
