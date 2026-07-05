import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/flipped_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum FlipDirection {
  horizontal(label: '水平翻转', value: 'horizontal'),
  vertical(label: '垂直翻转', value: 'vertical');

  const FlipDirection({required this.label, required this.value});

  final String label;
  final String value;
}

/// 图片翻转控制器，管理选图、翻转方向、执行状态和结果展示。
///
/// 异常策略：平台和文件异常统一转为中文提示；失败任务写入历史记录，便于
/// 用户后续在历史页通过状态筛选定位问题。
class FlipController extends GetxController {
  FlipController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  })  : _imageChannel = imageChannel,
        _historyRepository = historyRepository,
        _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<FlippedImageFile>();
  final direction = FlipDirection.horizontal.obs;
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

  void setDirection(FlipDirection value) {
    direction.value = value;
  }

  Future<void> flip() async {
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
      final flipped = await _imageChannel.flipImage(
        source: source,
        direction: direction.value.value,
      );
      result.value = flipped;
      await _historyRepository.recordOperationSuccess(
        featureName: '图片翻转',
        inputPath: source.path,
        outputPath: flipped.outputPath,
        parameters: <String, Object>{'direction': direction.value.value},
      );
      Get.snackbar('翻转完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片翻转',
        inputPath: source.path,
        parameters: <String, Object>{'direction': direction.value.value},
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

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
