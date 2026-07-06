import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/exif_cleaned_image_file.dart';
import '../../models/exif_info.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// EXIF 控制器，负责选择图片、读取元数据和导出去除 EXIF 的副本。
///
/// 异常策略：读取失败只展示错误，不写历史；删除 EXIF 属于会生成文件的任务，
/// 成功和失败都会写入历史。删除动作通过重新编码副本完成，避免覆盖原图。
class ExifController extends GetxController {
  ExifController({
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
  final exifInfo = Rxn<ExifInfo>();
  final cleanedResult = Rxn<ExifCleanedImageFile>();
  final isBusy = false.obs;

  Future<void> pickImage() async {
    if (isBusy.value) {
      return;
    }
    isBusy.value = true;
    try {
      final image = await _imageChannel.pickSingleImage();
      if (image == null) {
        return;
      }
      selectedImage.value = image;
      cleanedResult.value = null;
      await _recentFilesRepository.recordImage(image);
      await _readExif(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('exif.error.readFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> refreshExif() async {
    if (isBusy.value) {
      return;
    }
    final image = selectedImage.value;
    if (image == null) {
      _showError('exif.error.pickImageFirst'.tr);
      return;
    }
    isBusy.value = true;
    try {
      await _readExif(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('exif.error.readFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> removeExif() async {
    if (isBusy.value) {
      return;
    }
    final image = selectedImage.value;
    if (image == null) {
      _showError('exif.error.pickImageFirst'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final cleaned = await _imageChannel.removeExif(source: image);
      cleanedResult.value = cleaned;
      await _historyRepository.recordOperationSuccess(
        featureName: 'exif.featureName'.tr,
        inputPath: image.path,
        outputPath: cleaned.outputPath,
        parameters: <String, Object>{'mode': 'removeExif'},
      );
      showLatestSnackbar(
        'exif.remove.success.title'.tr,
        'exif.remove.success.message'.tr,
      );
    } on AppException catch (error) {
      await _recordRemoveFailure(image, error.message);
      _showError(error.message);
    } catch (_) {
      await _recordRemoveFailure(image, 'exif.error.removeFailedLog'.tr);
      _showError('exif.error.removeFailed'.tr);
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
      return 'exif.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  Future<void> _readExif(LocalImageFile image) async {
    exifInfo.value = await _imageChannel.readExif(source: image);
  }

  Future<void> _recordRemoveFailure(
    LocalImageFile image,
    String message,
  ) async {
    await _historyRepository.recordOperationFailure(
      featureName: 'exif.featureName'.tr,
      inputPath: image.path,
      parameters: const <String, Object>{'mode': 'removeExif'},
      errorMessage: message,
    );
  }

  void _showError(String message) {
    showLatestSnackbar('exif.error.title'.tr, message);
  }
}
