import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/exif_cleaned_image_file.dart';
import '../../core/models/exif_info.dart';
import '../../core/models/local_image_file.dart';
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
      _showError('读取 EXIF 失败，请重试');
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
      _showError('请先选择一张图片');
      return;
    }
    isBusy.value = true;
    try {
      await _readExif(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('读取 EXIF 失败，请重试');
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
      _showError('请先选择一张图片');
      return;
    }

    isBusy.value = true;
    try {
      final cleaned = await _imageChannel.removeExif(source: image);
      cleanedResult.value = cleaned;
      await _historyRepository.recordOperationSuccess(
        featureName: '删除 EXIF',
        inputPath: image.path,
        outputPath: cleaned.outputPath,
        parameters: <String, Object>{'mode': 'removeExif'},
      );
      Get.snackbar('删除完成', '已导出去除 EXIF 的图片副本');
    } on AppException catch (error) {
      await _recordRemoveFailure(image, error.message);
      _showError(error.message);
    } catch (_) {
      await _recordRemoveFailure(image, '删除 EXIF 失败');
      _showError('删除 EXIF 失败，请重试');
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

  Future<void> _readExif(LocalImageFile image) async {
    exifInfo.value = await _imageChannel.readExif(source: image);
  }

  Future<void> _recordRemoveFailure(
    LocalImageFile image,
    String message,
  ) async {
    await _historyRepository.recordOperationFailure(
      featureName: '删除 EXIF',
      inputPath: image.path,
      parameters: const <String, Object>{'mode': 'removeExif'},
      errorMessage: message,
    );
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
