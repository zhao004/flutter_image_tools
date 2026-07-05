import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/gif_frames_export.dart';
import '../../core/models/gif_image_file.dart';
import '../../core/models/local_image_file.dart';
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
  final delayMs = 300.obs;
  final frameStepMs = 200.obs;
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
        _showError('单次最多选择 30 张图片');
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

  Future<void> createGif() async {
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
      final gif = await _imageChannel.imagesToGif(
        sources: selectedImages.toList(growable: false),
        delayMs: delayMs.value,
      );
      result.value = gif;
      await _historyRepository.recordOperationSuccess(
        featureName: 'GIF 生成',
        inputPath: inputPath,
        outputPath: gif.outputPath,
        parameters: <String, Object>{
          'count': selectedImages.length,
          'delayMs': delayMs.value,
        },
      );
      Get.snackbar('GIF 已生成', '文件已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'GIF 生成',
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
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  Future<void> exportFrames() async {
    if (isBusy.value) {
      return;
    }
    final gif = selectedGif.value;
    if (gif == null) {
      _showError('请先选择 GIF 图片');
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
        featureName: 'GIF 拆帧',
        inputPath: gif.path,
        outputPath: export.outputDirectory,
        parameters: <String, Object>{
          'frameCount': export.frameCount,
          'durationMs': export.durationMs,
          'frameStepMs': export.frameStepMs,
        },
      );
      Get.snackbar('GIF 拆帧完成', '已导出 ${export.frameCount} 张 PNG 图片');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'GIF 拆帧',
        inputPath: gif.path,
        parameters: <String, Object>{'frameStepMs': frameStepMs.value},
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
