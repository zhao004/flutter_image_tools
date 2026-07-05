import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/filtered_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum ImageFilterType {
  grayscale(label: '灰度', value: 'grayscale'),
  monochrome(label: '黑白', value: 'monochrome'),
  sepia(label: '怀旧', value: 'sepia'),
  invert(label: '反色', value: 'invert'),
  warm(label: '暖色', value: 'warm'),
  cool(label: '冷色', value: 'cool');

  const ImageFilterType({required this.label, required this.value});

  final String label;
  final String value;
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
      _showError('记录最近文件失败，请重试');
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
      _showError('请先选择一张图片');
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
        featureName: '图片滤镜',
        inputPath: source.path,
        outputPath: filtered.outputPath,
        parameters: <String, Object>{'filter': filter.value.value},
      );
      Get.snackbar('滤镜完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片滤镜',
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
