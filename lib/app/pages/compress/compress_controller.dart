import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/compressed_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// 图片压缩控制器，管理选择、质量参数、执行状态和结果展示。
///
/// 异常策略：所有用户可恢复错误显示 Snackbar，并在已有输入文件时写入失败
/// 历史；未知错误由服务层包装，避免界面层直接处理平台异常。
class CompressController extends GetxController {
  CompressController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required AppSettingsRepository settingsRepository,
    required RecentFilesRepository recentFilesRepository,
  })  : _imageChannel = imageChannel,
        _historyRepository = historyRepository,
        _settingsRepository = settingsRepository,
        _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final AppSettingsRepository _settingsRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<CompressedImageFile>();
  final quality = 80.obs;
  final isBusy = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDefaultQuality();
  }

  Future<void> _loadDefaultQuality() async {
    try {
      quality.value = await _settingsRepository.getDefaultQuality();
    } catch (_) {
      quality.value = 80;
    }
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

  void updateQuality(double value) {
    quality.value = value.round().clamp(1, 100);
  }

  Future<void> compress() async {
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
      final compressed = await _imageChannel.compressImage(
        source: source,
        quality: quality.value,
      );
      result.value = compressed;
      await _historyRepository.recordCompressionSuccess(
        inputPath: source.path,
        outputPath: compressed.outputPath,
        quality: quality.value,
      );
      Get.snackbar('压缩完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordCompressionFailure(
        inputPath: source.path,
        quality: quality.value,
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
