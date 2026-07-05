import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/rotated_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// 图片旋转控制器，管理选图、角度设置、执行状态和旋转结果。
///
/// 异常策略：用户可恢复异常通过 Snackbar 提示；旋转失败写入历史记录，
/// 方便用户在历史页筛选失败任务并定位输入文件。
class RotateController extends GetxController {
  RotateController({
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
  final result = Rxn<RotatedImageFile>();
  final degrees = 90.obs;
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

  void setDegrees(int value) {
    degrees.value = value.clamp(-360, 360);
  }

  void updateCustomDegrees(double value) {
    degrees.value = value.round().clamp(-180, 180);
  }

  Future<void> rotate() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('请先选择一张图片');
      return;
    }
    if (degrees.value == 0) {
      _showError('旋转角度不能为 0');
      return;
    }

    isBusy.value = true;
    try {
      final rotated = await _imageChannel.rotateImage(
        source: source,
        degrees: degrees.value,
      );
      result.value = rotated;
      await _historyRepository.recordOperationSuccess(
        featureName: '图片旋转',
        inputPath: source.path,
        outputPath: rotated.outputPath,
        parameters: <String, Object>{'degrees': degrees.value},
      );
      Get.snackbar('旋转完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片旋转',
        inputPath: source.path,
        parameters: <String, Object>{'degrees': degrees.value},
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
