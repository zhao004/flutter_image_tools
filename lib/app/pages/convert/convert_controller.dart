import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/converted_image_file.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum ConvertFormat {
  jpg(label: 'JPG', value: 'jpg'),
  png(label: 'PNG', value: 'png'),
  webp(label: 'WebP', value: 'webp'),
  bmp(label: 'BMP', value: 'bmp');

  const ConvertFormat({required this.label, required this.value});

  final String label;
  final String value;
}

/// 图片格式转换控制器，管理选图、目标格式、导出质量和转换结果。
///
/// 异常策略：格式和质量在发起原生调用前完成校验；转换失败写入历史记录，
/// 用户可以在历史页回看源文件、目标格式和错误原因。
class ConvertController extends GetxController {
  ConvertController({
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
  final result = Rxn<ConvertedImageFile>();
  final format = ConvertFormat.jpg.obs;
  final quality = 95.obs;
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

  void setFormat(ConvertFormat value) {
    format.value = value;
  }

  void updateQuality(double value) {
    quality.value = value.round().clamp(1, 100);
  }

  Future<void> convert() async {
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
      final converted = await _imageChannel.convertImage(
        source: source,
        format: format.value.value,
        quality: quality.value,
      );
      result.value = converted;
      await _historyRepository.recordOperationSuccess(
        featureName: '格式转换',
        inputPath: source.path,
        outputPath: converted.outputPath,
        parameters: <String, Object>{
          'format': format.value.value,
          'quality': quality.value,
        },
      );
      Get.snackbar('格式转换完成', '图片已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '格式转换',
        inputPath: source.path,
        parameters: <String, Object>{
          'format': format.value.value,
          'quality': quality.value,
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

  String formatDimensions(LocalImageFile image) {
    if (!image.hasValidDimensions) {
      return '未知尺寸';
    }
    return '${image.width} × ${image.height} px';
  }

  String qualityHint() {
    return switch (format.value) {
      ConvertFormat.jpg || ConvertFormat.webp => 'JPG 和 WebP 会使用导出质量。',
      ConvertFormat.png || ConvertFormat.bmp => 'PNG 和 BMP 为无损导出，质量参数会被忽略。',
    };
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
