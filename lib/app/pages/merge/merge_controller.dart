import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/merged_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum MergeMode {
  horizontal(label: '横向拼接', value: 'horizontal'),
  vertical(label: '纵向拼接', value: 'vertical'),
  grid(label: '网格拼接', value: 'grid');

  const MergeMode({required this.label, required this.value});

  final String label;
  final String value;
}

/// 图片拼接控制器，管理批量选图、布局模式、网格列数、间距和拼接结果。
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
  final columns = 2.obs;
  final spacing = 8.obs;
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
        _showError('单次最多拼接 20 张图片');
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
      _showError('记录最近文件失败，请重试');
    }
  }

  void setMode(MergeMode value) {
    mode.value = value;
  }

  void updateColumns(double value) {
    columns.value = value.round().clamp(1, 10);
  }

  void updateSpacing(double value) {
    spacing.value = value.round().clamp(0, 100);
  }

  Future<void> merge() async {
    if (isBusy.value) {
      return;
    }
    if (selectedImages.length < 2) {
      _showError('请至少选择两张图片');
      return;
    }

    isBusy.value = true;
    final inputPath = selectedImages.map((image) => image.path).join('|');
    try {
      final merged = await _imageChannel.mergeImages(
        sources: selectedImages.toList(growable: false),
        mode: mode.value.value,
        columns: columns.value,
        spacing: spacing.value,
      );
      result.value = merged;
      await _historyRepository.recordOperationSuccess(
        featureName: '图片拼接',
        inputPath: inputPath,
        outputPath: merged.outputPath,
        parameters: <String, Object>{
          'mode': mode.value.value,
          'count': selectedImages.length,
          'columns': columns.value,
          'spacing': spacing.value,
        },
      );
      Get.snackbar('拼接完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片拼接',
        inputPath: inputPath,
        parameters: <String, Object>{
          'mode': mode.value.value,
          'count': selectedImages.length,
          'columns': columns.value,
          'spacing': spacing.value,
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

  int get totalSizeBytes =>
      selectedImages.fold<int>(0, (sum, image) => sum + image.sizeBytes);

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
