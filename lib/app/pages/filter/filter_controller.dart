import 'package:get/get.dart';

import '../../exceptions/app_exception.dart';
import '../../models/filtered_image_file.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum ImageFilterType {
  grayscale(labelKey: 'filter.type.grayscale', value: 'grayscale'),
  monochrome(labelKey: 'filter.type.monochrome', value: 'monochrome'),
  sepia(labelKey: 'filter.type.sepia', value: 'sepia'),
  invert(labelKey: 'filter.type.invert', value: 'invert'),
  warm(labelKey: 'filter.type.warm', value: 'warm'),
  cool(labelKey: 'filter.type.cool', value: 'cool'),
  hdr(labelKey: 'filter.type.hdr', value: 'hdr'),
  film(labelKey: 'filter.type.film', value: 'film'),
  sharpen(labelKey: 'filter.type.sharpen', value: 'sharpen'),
  soften(labelKey: 'filter.type.soften', value: 'soften');

  const ImageFilterType({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  String get label => labelKey.tr;
}

/// 图片滤镜控制器，管理选图、滤镜选择、执行状态和导出结果。
///
/// 异常策略：滤镜类型在 Dart 侧白名单校验，平台异常统一转换为中文提示；
/// 失败任务写入历史，方便用户回看源文件和失败参数。
class FilterController extends GetxController {
  FilterController({
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
  final result = Rxn<FilteredImageFile>();
  final filter = ImageFilterType.grayscale.obs;
  final isBusy = false.obs;

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
      _showError('filter.error.recentFileFailed'.tr);
    }
  }

  void setFilter(ImageFilterType value) {
    filter.value = value;
  }

  Future<void> applyFilter() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('filter.error.pickImageFirst'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final filtered = await _imageChannel.applyFilter(
        source: source,
        filter: filter.value.value,
      );
      result.value = filtered;
      await _historyRepository.recordOperationSuccess(
        featureName: 'filter.featureName'.tr,
        inputPath: source.path,
        outputPath: filtered.outputPath,
        parameters: <String, Object>{'filter': filter.value.value},
      );
      Get.snackbar(
        'filter.apply.success.title'.tr,
        'filter.apply.success.message'.tr,
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'filter.featureName'.tr,
        inputPath: source.path,
        parameters: <String, Object>{'filter': filter.value.value},
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
      return 'filter.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  String labelForFilterValue(String value) {
    for (final item in ImageFilterType.values) {
      if (item.value == value) {
        return item.label;
      }
    }
    return value;
  }

  void _showError(String message) {
    Get.snackbar('filter.error.title'.tr, message);
  }
}
