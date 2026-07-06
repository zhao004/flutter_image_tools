import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/compressed_gif_file.dart';
import '../../models/gif_frames_export.dart';
import '../../models/gif_image_file.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// GIF 工具控制器，管理批量选图、帧间隔校验和本地 GIF 生成结果。
///
/// 异常策略：Dart 侧先限制图片数量和帧延迟，Android 侧继续校验文件、
/// 解码尺寸和 GIF 写入状态；失败会写入历史记录，便于定位输入组合。
class GifController extends GetxController {
  GifController({
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
  final result = Rxn<GifImageFile>();
  final selectedGif = Rxn<LocalImageFile>();
  final framesExport = Rxn<GifFramesExport>();
  final compressedGif = Rxn<CompressedGifFile>();
  final delayMs = 300.obs;
  final frameStepMs = 200.obs;
  final compressFrameStepMs = 250.obs;
  final compressScalePercent = 60.obs;
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
      if (images.length > LocalImageChannel.maxGifImages) {
        _showError(
          'gif.error.tooManyImages'.trParams({
            'max': LocalImageChannel.maxGifImages.toString(),
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
      _showError('gif.error.recentFileFailed'.tr);
    }
  }

  void updateDelay(double value) {
    delayMs.value = value.round().clamp(
      LocalImageChannel.minGifDelayMs,
      LocalImageChannel.maxGifDelayMs,
    );
  }

  void updateFrameStep(double value) {
    frameStepMs.value = value.round().clamp(
      LocalImageChannel.minGifFrameStepMs,
      LocalImageChannel.maxGifFrameStepMs,
    );
  }

  void updateCompressFrameStep(double value) {
    compressFrameStepMs.value = value.round().clamp(
      LocalImageChannel.minGifFrameStepMs,
      LocalImageChannel.maxGifFrameStepMs,
    );
  }

  void updateCompressScale(double value) {
    compressScalePercent.value = value.round().clamp(
      LocalImageChannel.minGifScalePercent,
      LocalImageChannel.maxGifScalePercent,
    );
  }

  Future<void> createGif() async {
    if (isBusy.value) {
      return;
    }
    if (selectedImages.length < 2) {
      _showError('gif.error.minImages'.tr);
      return;
    }

    isBusy.value = true;
    final inputPath = selectedImages.map((image) => image.path).join('|');
    try {
      final gif = await _imageChannel.imagesToGif(
        sources: selectedImages.toList(growable: false),
        delayMs: delayMs.value,
      );
      result.value = gif;
      await _historyRepository.recordOperationSuccess(
        featureName: 'gif.feature.create'.tr,
        inputPath: inputPath,
        outputPath: gif.outputPath,
        parameters: <String, Object>{
          'count': selectedImages.length,
          'delayMs': delayMs.value,
        },
      );
      showLatestSnackbar(
        'gif.success.created.title'.tr,
        'gif.success.created.message'.tr,
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'gif.feature.create'.tr,
        inputPath: inputPath,
        parameters: <String, Object>{
          'count': selectedImages.length,
          'delayMs': delayMs.value,
        },
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> pickGif() async {
    if (isBusy.value) {
      return;
    }
    try {
      final image = await _imageChannel.pickSingleImage();
      if (image == null) {
        return;
      }
      selectedGif.value = image;
      framesExport.value = null;
      compressedGif.value = null;
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('gif.error.recentFileFailed'.tr);
    }
  }

  Future<void> exportFrames() async {
    if (isBusy.value) {
      return;
    }
    final gif = selectedGif.value;
    if (gif == null) {
      _showError('gif.error.pickGifFirst'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final export = await _imageChannel.exportGifFrames(
        source: gif,
        frameStepMs: frameStepMs.value,
      );
      framesExport.value = export;
      await _historyRepository.recordOperationSuccess(
        featureName: 'gif.feature.exportFrames'.tr,
        inputPath: gif.path,
        outputPath: export.outputDirectory,
        parameters: <String, Object>{
          'frameCount': export.frameCount,
          'durationMs': export.durationMs,
          'frameStepMs': export.frameStepMs,
        },
      );
      showLatestSnackbar(
        'gif.success.framesExported.title'.tr,
        'gif.success.framesExported.message'.trParams({
          'count': export.frameCount.toString(),
        }),
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'gif.feature.exportFrames'.tr,
        inputPath: gif.path,
        parameters: <String, Object>{'frameStepMs': frameStepMs.value},
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> compressSelectedGif() async {
    if (isBusy.value) {
      return;
    }
    final gif = selectedGif.value;
    if (gif == null) {
      _showError('gif.error.pickGifFirst'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final compressed = await _imageChannel.compressGif(
        source: gif,
        frameStepMs: compressFrameStepMs.value,
        scalePercent: compressScalePercent.value,
      );
      compressedGif.value = compressed;
      await _historyRepository.recordOperationSuccess(
        featureName: 'gif.feature.compress'.tr,
        inputPath: gif.path,
        outputPath: compressed.outputPath,
        parameters: <String, Object>{
          'frameCount': compressed.frameCount,
          'frameStepMs': compressed.frameStepMs,
          'scalePercent': compressed.scalePercent,
          'savedSizeBytes': compressed.savedSizeBytes,
        },
      );
      showLatestSnackbar(
        'gif.success.compressed.title'.tr,
        'gif.success.compressed.message'.tr,
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'gif.feature.compress'.tr,
        inputPath: gif.path,
        parameters: <String, Object>{
          'frameStepMs': compressFrameStepMs.value,
          'scalePercent': compressScalePercent.value,
        },
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
  }

  int get totalSizeBytes =>
      selectedImages.fold<int>(0, (sum, image) => sum + image.sizeBytes);

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

  String formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  void _showError(String message) {
    showLatestSnackbar('gif.error.title'.tr, message);
  }
}
