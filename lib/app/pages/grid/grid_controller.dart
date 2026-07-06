import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/grid_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// 九宫格切图控制器，管理选图、网格大小、执行状态和导出结果。
///
/// 异常策略：网格范围在 Dart 和 Android 双层校验；失败时写入历史记录，
/// 让用户可以追踪源文件、参数和失败原因。
class GridController extends GetxController {
  GridController({
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
  final result = Rxn<GridImageFile>();
  final gridSize = 3.obs;
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
      _showError('grid.error.recentFileFailed'.tr);
    }
  }

  void setGridSize(int value) {
    if (value < LocalImageChannel.minGridSize ||
        value > LocalImageChannel.maxGridSize) {
      _showError('grid.error.invalidSize'.tr);
      return;
    }
    gridSize.value = value;
  }

  Future<void> splitImage() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('grid.error.pickImageFirst'.tr);
      return;
    }

    isBusy.value = true;
    final currentGridSize = gridSize.value;
    try {
      final gridImage = await _imageChannel.splitGridImage(
        source: source,
        gridSize: currentGridSize,
      );
      result.value = gridImage;
      await _historyRepository.recordOperationSuccess(
        featureName: 'grid.featureName'.tr,
        inputPath: source.path,
        outputPath: gridImage.outputDirectory,
        parameters: <String, Object>{
          'gridSize': currentGridSize,
          'pieceCount': gridImage.pieceCount,
        },
      );
      Get.snackbar(
        'grid.split.success.title'.tr,
        'grid.split.success.message'.trParams({
          'count': '${gridImage.pieceCount}',
        }),
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'grid.featureName'.tr,
        inputPath: source.path,
        parameters: <String, Object>{'gridSize': currentGridSize},
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
      return 'grid.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  void _showError(String message) {
    Get.snackbar('grid.error.title'.tr, message);
  }
}
