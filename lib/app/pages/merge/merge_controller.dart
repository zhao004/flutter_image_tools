import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/local_image_file.dart';
import '../../models/merged_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum MergeMode {
  horizontal(
    labelKey: 'merge.mode.horizontal',
    value: 'horizontal',
    scaleModeValue: 'same_height',
  ),
  vertical(
    labelKey: 'merge.mode.vertical',
    value: 'vertical',
    scaleModeValue: 'same_width',
  );

  const MergeMode({
    required this.labelKey,
    required this.value,
    required this.scaleModeValue,
  });

  final String labelKey;
  final String value;
  final String scaleModeValue;
}

enum MergeBackgroundColor {
  white(labelKey: 'merge.color.white', value: '#FFFFFF'),
  lightGray(labelKey: 'merge.color.lightGray', value: '#F2F2F2'),
  black(labelKey: 'merge.color.black', value: '#000000'),
  darkGray(labelKey: 'merge.color.darkGray', value: '#333333');

  const MergeBackgroundColor({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum MergeBorderColor {
  black(labelKey: 'merge.color.black', value: '#000000'),
  white(labelKey: 'merge.color.white', value: '#FFFFFF'),
  gray(labelKey: 'merge.color.gray', value: '#808080'),
  red(labelKey: 'merge.color.red', value: '#D32F2F');

  const MergeBorderColor({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum MergeToolbarTab {
  layout(labelKey: 'merge.tool.layout', icon: 'layout'),
  style(labelKey: 'merge.tool.style', icon: 'style'),
  order(labelKey: 'merge.tool.order', icon: 'order');

  const MergeToolbarTab({required this.labelKey, required this.icon});

  final String labelKey;
  final String icon;
}

/// 图片拼接控制器，管理批量选图、工具分组、布局参数和拼接结果。
///
/// 异常策略：Dart 侧限制图片数量和布局参数，Android 侧再校验文件与输出
/// 画布大小，避免超大图片组合导致内存不足。
class MergeController extends GetxController {
  MergeController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImages = <LocalImageFile>[].obs;
  final result = Rxn<MergedImageFile>();
  final mode = MergeMode.horizontal.obs;
  final backgroundColor = MergeBackgroundColor.white.obs;
  final borderColor = MergeBorderColor.black.obs;
  final spacing = 8.obs;
  final borderWidth = 0.obs;
  final cornerRadius = 0.obs;
  final toolbarTab = MergeToolbarTab.layout.obs;
  final isBusy = false.obs;

  Future<void> pickImages() async {
    if (isBusy.value) {
      return;
    }
    try {
      final images = await _imageChannel.pickMultipleImages();
      if (images.isEmpty) {
        return;
      }
      if (images.length > LocalImageChannel.maxMergeImages) {
        _showError(
          'merge.error.tooManyImages'.trParams({
            'max': LocalImageChannel.maxMergeImages.toString(),
          }),
        );
        return;
      }
      selectedImages.assignAll(images);
      result.value = null;
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('merge.error.recentFileFailed'.tr);
    }
  }

  void setMode(MergeMode value) {
    mode.value = value;
  }

  void setBackgroundColor(MergeBackgroundColor value) {
    backgroundColor.value = value;
  }

  void setBorderColor(MergeBorderColor value) {
    borderColor.value = value;
  }

  void setToolbarTab(MergeToolbarTab value) {
    toolbarTab.value = value;
  }

  void reorderSelectedImages(int oldIndex, int newIndex) {
    if (isBusy.value) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= selectedImages.length) {
      return;
    }
    final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (targetIndex < 0 || targetIndex >= selectedImages.length) {
      return;
    }
    if (oldIndex == targetIndex) {
      return;
    }

    final image = selectedImages.removeAt(oldIndex);
    selectedImages.insert(targetIndex, image);
    result.value = null;
  }

  void updateSpacing(double value) {
    spacing.value = value.round().clamp(0, 100);
  }

  void updateBorderWidth(double value) {
    borderWidth.value = value.round().clamp(0, 50);
  }

  void updateCornerRadius(double value) {
    cornerRadius.value = value.round().clamp(0, 200);
  }

  Future<void> merge() async {
    if (isBusy.value) {
      return;
    }
    if (selectedImages.length < 2) {
      _showError('merge.error.minImages'.tr);
      return;
    }

    isBusy.value = true;
    final inputPath = selectedImages.map((image) => image.path).join('|');
    try {
      final merged = await _imageChannel.mergeImages(
        sources: selectedImages.toList(growable: false),
        mode: mode.value.value,
        spacing: spacing.value,
        backgroundColor: backgroundColor.value.value,
        borderWidth: borderWidth.value,
        borderColor: borderColor.value.value,
        cornerRadius: cornerRadius.value,
        scaleMode: mode.value.scaleModeValue,
      );
      result.value = merged;
      await _historyRepository.recordOperationSuccess(
        featureName: 'merge.featureName'.tr,
        inputPath: inputPath,
        outputPath: merged.outputPath,
        parameters: <String, Object>{
          'mode': mode.value.value,
          'count': selectedImages.length,
          'spacing': spacing.value,
          'backgroundColor': backgroundColor.value.value,
          'borderWidth': borderWidth.value,
          'borderColor': borderColor.value.value,
          'cornerRadius': cornerRadius.value,
          'scaleMode': mode.value.scaleModeValue,
        },
      );
      showLatestSnackbar('merge.success.title'.tr, 'merge.success.message'.tr);
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'merge.featureName'.tr,
        inputPath: inputPath,
        parameters: <String, Object>{
          'mode': mode.value.value,
          'count': selectedImages.length,
          'spacing': spacing.value,
          'backgroundColor': backgroundColor.value.value,
          'borderWidth': borderWidth.value,
          'borderColor': borderColor.value.value,
          'cornerRadius': cornerRadius.value,
          'scaleMode': mode.value.scaleModeValue,
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

  int get totalSizeBytes =>
      selectedImages.fold<int>(0, (sum, image) => sum + image.sizeBytes);

  void _showError(String message) {
    showLatestSnackbar('merge.error.title'.tr, message);
  }
}
