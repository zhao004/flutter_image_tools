import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/local_image_file.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum BatchOperation {
  compress(
    labelKey: 'batch.operation.compress',
    featureKey: 'batch.feature.compress',
  ),
  convert(
    labelKey: 'batch.operation.convert',
    featureKey: 'batch.feature.convert',
  ),
  rotate(
    labelKey: 'batch.operation.rotate',
    featureKey: 'batch.feature.rotate',
  ),
  flip(labelKey: 'batch.operation.flip', featureKey: 'batch.feature.flip'),
  resize(
    labelKey: 'batch.operation.resize',
    featureKey: 'batch.feature.resize',
  ),
  textWatermark(
    labelKey: 'batch.operation.textWatermark',
    featureKey: 'batch.feature.textWatermark',
  ),
  imageWatermark(
    labelKey: 'batch.operation.imageWatermark',
    featureKey: 'batch.feature.imageWatermark',
  ),
  filter(
    labelKey: 'batch.operation.filter',
    featureKey: 'batch.feature.filter',
  ),
  crop(labelKey: 'batch.operation.crop', featureKey: 'batch.feature.crop'),
  removeExif(
    labelKey: 'batch.operation.removeExif',
    featureKey: 'batch.feature.removeExif',
  ),
  grid(labelKey: 'batch.operation.grid', featureKey: 'batch.feature.grid'),
  scanCode(
    labelKey: 'batch.operation.scanCode',
    featureKey: 'batch.feature.scanCode',
  ),
  base64Encode(
    labelKey: 'batch.operation.base64Encode',
    featureKey: 'batch.feature.base64Encode',
  );

  const BatchOperation({required this.labelKey, required this.featureKey});

  final String labelKey;
  final String featureKey;
}

enum BatchConvertFormat {
  jpg(label: 'JPG', value: 'jpg'),
  png(label: 'PNG', value: 'png'),
  webp(label: 'WebP', value: 'webp'),
  bmp(label: 'BMP', value: 'bmp');

  const BatchConvertFormat({required this.label, required this.value});

  final String label;
  final String value;
}

enum BatchFlipDirection {
  horizontal(labelKey: 'batch.flip.horizontal', value: 'horizontal'),
  vertical(labelKey: 'batch.flip.vertical', value: 'vertical');

  const BatchFlipDirection({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum BatchResizeMode {
  percent(labelKey: 'batch.resizeMode.percent', value: 'percent'),
  exact(labelKey: 'batch.resizeMode.exact', value: 'exact');

  const BatchResizeMode({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum BatchWatermarkPosition {
  topLeft(labelKey: 'batch.position.topLeft', value: 'topLeft'),
  topRight(labelKey: 'batch.position.topRight', value: 'topRight'),
  bottomLeft(labelKey: 'batch.position.bottomLeft', value: 'bottomLeft'),
  bottomRight(labelKey: 'batch.position.bottomRight', value: 'bottomRight'),
  center(labelKey: 'batch.position.center', value: 'center'),
  tile(labelKey: 'batch.position.tile', value: 'tile');

  const BatchWatermarkPosition({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum BatchWatermarkColor {
  white(labelKey: 'batch.color.white', value: '#FFFFFF'),
  black(labelKey: 'batch.color.black', value: '#000000'),
  red(labelKey: 'batch.color.red', value: '#E53935'),
  yellow(labelKey: 'batch.color.yellow', value: '#FDD835');

  const BatchWatermarkColor({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum BatchFilterType {
  grayscale(labelKey: 'batch.filter.grayscale', value: 'grayscale'),
  monochrome(labelKey: 'batch.filter.monochrome', value: 'monochrome'),
  sepia(labelKey: 'batch.filter.sepia', value: 'sepia'),
  invert(labelKey: 'batch.filter.invert', value: 'invert'),
  warm(labelKey: 'batch.filter.warm', value: 'warm'),
  cool(labelKey: 'batch.filter.cool', value: 'cool'),
  hdr(labelKey: 'batch.filter.hdr', value: 'hdr'),
  film(labelKey: 'batch.filter.film', value: 'film'),
  sharpen(labelKey: 'batch.filter.sharpen', value: 'sharpen'),
  soften(labelKey: 'batch.filter.soften', value: 'soften');

  const BatchFilterType({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum BatchCropPreset {
  square(labelKey: 'batch.cropPreset.square', ratioText: '1:1', aspectRatio: 1),
  landscape16x9(
    labelKey: 'batch.cropPreset.landscape16x9',
    ratioText: '16:9',
    aspectRatio: 16 / 9,
  ),
  landscape4x3(
    labelKey: 'batch.cropPreset.landscape4x3',
    ratioText: '4:3',
    aspectRatio: 4 / 3,
  ),
  portrait9x16(
    labelKey: 'batch.cropPreset.portrait9x16',
    ratioText: '9:16',
    aspectRatio: 9 / 16,
  ),
  custom(
    labelKey: 'batch.cropPreset.custom',
    ratioText: 'batch.cropPreset.customRatio',
    aspectRatio: 1,
  );

  const BatchCropPreset({
    required this.labelKey,
    required this.ratioText,
    required this.aspectRatio,
  });

  final String labelKey;
  final String ratioText;
  final double aspectRatio;
}

enum BatchTaskStatus {
  pending(labelKey: 'batch.status.pending'),
  running(labelKey: 'batch.status.running'),
  paused(labelKey: 'batch.status.paused'),
  success(labelKey: 'batch.status.success'),
  failed(labelKey: 'batch.status.failed'),
  canceled(labelKey: 'batch.status.canceled');

  const BatchTaskStatus({required this.labelKey});

  final String labelKey;
}

class BatchImageTask {
  const BatchImageTask({
    required this.source,
    this.outputPath = '',
    this.outputSizeBytes = 0,
    this.resultLabel = '',
    this.resultText = '',
    this.errorMessage,
    this.status = BatchTaskStatus.pending,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final String resultLabel;
  final String resultText;
  final String? errorMessage;
  final BatchTaskStatus status;

  bool get isTerminal =>
      status == BatchTaskStatus.success ||
      status == BatchTaskStatus.failed ||
      status == BatchTaskStatus.canceled;

  bool get canRetry => status == BatchTaskStatus.failed;

  BatchImageTask copyWith({
    String? outputPath,
    int? outputSizeBytes,
    String? resultLabel,
    String? resultText,
    String? errorMessage,
    BatchTaskStatus? status,
    bool clearError = false,
  }) {
    return BatchImageTask(
      source: source,
      outputPath: outputPath ?? this.outputPath,
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
      resultLabel: resultLabel ?? this.resultLabel,
      resultText: resultText ?? this.resultText,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }
}

/// 批量处理控制器，提供集中式批量压缩队列。
///
/// 设计意图：先用现有本地压缩能力建立可暂停、继续、取消和失败重试的队列
/// 骨架；后续裁剪、旋转、格式转换等批量任务可沿用同一状态模型扩展。
/// 异常策略：单个任务失败不会中断队列，错误写入历史并展示在任务行内。
class BatchController extends GetxController {
  static const int _minResizeDimension = 1;
  static const int _maxResizeDimension = LocalImageChannel.maxResizeDimension;
  static const int _maxBase64InputBytes = 12 * 1024 * 1024;

  BatchController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required AppSettingsRepository settingsRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _settingsRepository = settingsRepository,
       _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final AppSettingsRepository _settingsRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImages = <LocalImageFile>[].obs;
  final tasks = <BatchImageTask>[].obs;
  final operation = BatchOperation.compress.obs;
  final convertFormat = BatchConvertFormat.jpg.obs;
  final flipDirection = BatchFlipDirection.horizontal.obs;
  final resizeMode = BatchResizeMode.percent.obs;
  final resizePercent = 100.obs;
  final resizeWidth = 1024.obs;
  final resizeHeight = 1024.obs;
  final watermarkText = 'Image Toolkit'.obs;
  final watermarkPosition = BatchWatermarkPosition.bottomRight.obs;
  final watermarkColor = BatchWatermarkColor.white.obs;
  final watermarkFontSize = 36.obs;
  final watermarkOpacity = 70.obs;
  final imageWatermark = Rxn<LocalImageFile>();
  final imageWatermarkPosition = BatchWatermarkPosition.bottomRight.obs;
  final imageWatermarkOpacity = 70.obs;
  final imageWatermarkScale = 25.obs;
  final imageWatermarkRotation = 0.obs;
  final filter = BatchFilterType.grayscale.obs;
  final cropPreset = BatchCropPreset.square.obs;
  final cropRatioWidth = 1.obs;
  final cropRatioHeight = 1.obs;
  final gridSize = 3.obs;
  final degrees = 90.obs;
  final quality = 80.obs;
  final processedCount = 0.obs;
  final isRunning = false.obs;
  final isPaused = false.obs;
  final isCancelRequested = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDefaultQuality();
    _loadDefaultExportFormat();
  }

  Future<void> _loadDefaultQuality() async {
    try {
      quality.value = await _settingsRepository.getDefaultQuality();
    } catch (_) {
      quality.value = 80;
    }
  }

  Future<void> _loadDefaultExportFormat() async {
    try {
      convertFormat.value = _batchConvertFormatForValue(
        await _settingsRepository.getDefaultExportFormat(),
      );
    } catch (_) {
      convertFormat.value = BatchConvertFormat.jpg;
    }
  }

  Future<void> pickImages() async {
    if (isRunning.value) {
      return;
    }
    try {
      final images = await _imageChannel.pickMultipleImages();
      if (images.isEmpty) {
        return;
      }
      selectedImages.assignAll(images);
      tasks.assignAll(images.map((image) => BatchImageTask(source: image)));
      processedCount.value = 0;
      isPaused.value = false;
      isCancelRequested.value = false;
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('batch.error.recentFileFailed'.tr);
    }
  }

  Future<void> pickImageWatermark() async {
    if (isRunning.value) {
      return;
    }
    try {
      final image = await _imageChannel.pickSingleImage();
      if (image == null) {
        return;
      }
      imageWatermark.value = image;
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('batch.error.recentFileFailed'.tr);
    }
  }

  void updateQuality(double value) {
    if (isRunning.value) {
      return;
    }
    quality.value = value.round().clamp(1, 100);
  }

  void setOperation(BatchOperation value) {
    if (isRunning.value) {
      return;
    }
    operation.value = value;
    _resetTasksForCurrentSelection();
  }

  void setConvertFormat(BatchConvertFormat value) {
    if (isRunning.value) {
      return;
    }
    convertFormat.value = value;
  }

  void setFlipDirection(BatchFlipDirection value) {
    if (isRunning.value) {
      return;
    }
    flipDirection.value = value;
  }

  void setDegrees(int value) {
    if (isRunning.value) {
      return;
    }
    degrees.value = value.clamp(-360, 360);
  }

  void setResizeMode(BatchResizeMode value) {
    if (isRunning.value) {
      return;
    }
    resizeMode.value = value;
  }

  void updateResizePercent(double value) {
    if (isRunning.value) {
      return;
    }
    resizePercent.value = value.round().clamp(10, 300);
  }

  void updateResizeWidth(String value) {
    if (isRunning.value) {
      return;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return;
    }
    resizeWidth.value = parsed.clamp(_minResizeDimension, _maxResizeDimension);
  }

  void updateResizeHeight(String value) {
    if (isRunning.value) {
      return;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return;
    }
    resizeHeight.value = parsed.clamp(_minResizeDimension, _maxResizeDimension);
  }

  void updateWatermarkText(String value) {
    if (isRunning.value) {
      return;
    }
    watermarkText.value = value;
  }

  void setWatermarkPosition(BatchWatermarkPosition value) {
    if (isRunning.value) {
      return;
    }
    watermarkPosition.value = value;
  }

  void setWatermarkColor(BatchWatermarkColor value) {
    if (isRunning.value) {
      return;
    }
    watermarkColor.value = value;
  }

  void updateWatermarkFontSize(double value) {
    if (isRunning.value) {
      return;
    }
    watermarkFontSize.value = value.round().clamp(12, 160);
  }

  void updateWatermarkOpacity(double value) {
    if (isRunning.value) {
      return;
    }
    watermarkOpacity.value = value.round().clamp(10, 100);
  }

  void setImageWatermarkPosition(BatchWatermarkPosition value) {
    if (isRunning.value) {
      return;
    }
    imageWatermarkPosition.value = value;
  }

  void updateImageWatermarkOpacity(double value) {
    if (isRunning.value) {
      return;
    }
    imageWatermarkOpacity.value = value.round().clamp(10, 100);
  }

  void updateImageWatermarkScale(double value) {
    if (isRunning.value) {
      return;
    }
    imageWatermarkScale.value = value.round().clamp(5, 100);
  }

  void updateImageWatermarkRotation(double value) {
    if (isRunning.value) {
      return;
    }
    imageWatermarkRotation.value = value.round().clamp(-180, 180);
  }

  void setFilter(BatchFilterType value) {
    if (isRunning.value) {
      return;
    }
    filter.value = value;
  }

  void setCropPreset(BatchCropPreset value) {
    if (isRunning.value) {
      return;
    }
    cropPreset.value = value;
  }

  void updateCropRatioWidth(String value) {
    if (isRunning.value) {
      return;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return;
    }
    cropRatioWidth.value = parsed.clamp(1, 100);
  }

  void updateCropRatioHeight(String value) {
    if (isRunning.value) {
      return;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return;
    }
    cropRatioHeight.value = parsed.clamp(1, 100);
  }

  void setGridSize(int value) {
    if (isRunning.value) {
      return;
    }
    if (value < LocalImageChannel.minGridSize ||
        value > LocalImageChannel.maxGridSize) {
      _showError(
        'batch.error.gridSizeRange'.trParams({
          'min': LocalImageChannel.minGridSize.toString(),
          'max': LocalImageChannel.maxGridSize.toString(),
        }),
      );
      return;
    }
    gridSize.value = value;
  }

  Future<void> startQueue() async {
    if (isRunning.value) {
      return;
    }
    if (selectedImages.isEmpty) {
      _showError('batch.error.pickImagesFirst'.tr);
      return;
    }
    if (operation.value == BatchOperation.rotate && degrees.value == 0) {
      _showError('batch.error.zeroRotation'.tr);
      return;
    }
    if (operation.value == BatchOperation.resize &&
        !_hasValidResizeSettings()) {
      return;
    }
    if (operation.value == BatchOperation.textWatermark &&
        !_hasValidWatermarkSettings()) {
      return;
    }
    if (operation.value == BatchOperation.imageWatermark &&
        !_hasValidImageWatermarkSettings()) {
      return;
    }
    if (operation.value == BatchOperation.crop && _cropAspectRatio() == null) {
      return;
    }
    _resetTasksForCurrentSelection();
    processedCount.value = 0;
    isPaused.value = false;
    isCancelRequested.value = false;
    await _runQueue(onlyRetryFailed: false);
  }

  void pauseQueue() {
    if (!isRunning.value) {
      return;
    }
    isPaused.value = true;
    _markPendingAsPaused();
  }

  Future<void> resumeQueue() async {
    if (isRunning.value) {
      isPaused.value = false;
      _restorePausedToPending();
      return;
    }
    if (!tasks.any((task) => task.status == BatchTaskStatus.paused)) {
      return;
    }
    isPaused.value = false;
    isCancelRequested.value = false;
    _restorePausedToPending();
    await _runQueue(onlyRetryFailed: false);
  }

  void cancelQueue() {
    if (!isRunning.value && tasks.isEmpty) {
      return;
    }
    isCancelRequested.value = true;
    isPaused.value = false;
    for (var index = 0; index < tasks.length; index++) {
      final status = tasks[index].status;
      if (status == BatchTaskStatus.pending ||
          status == BatchTaskStatus.paused) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.canceled);
      }
    }
  }

  Future<void> retryFailed() async {
    if (isRunning.value) {
      return;
    }
    if (!tasks.any((task) => task.canRetry)) {
      _showError('batch.error.noFailedTasks'.tr);
      return;
    }
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].canRetry) {
        tasks[index] = tasks[index].copyWith(
          status: BatchTaskStatus.pending,
          clearError: true,
        );
      }
    }
    isPaused.value = false;
    isCancelRequested.value = false;
    await _runQueue(onlyRetryFailed: true);
  }

  Future<void> _runQueue({required bool onlyRetryFailed}) async {
    isRunning.value = true;
    try {
      for (var index = 0; index < tasks.length; index++) {
        if (isCancelRequested.value) {
          _markPendingAsCanceled();
          break;
        }
        if (isPaused.value) {
          _markPendingAsPaused();
          break;
        }
        if (tasks[index].status != BatchTaskStatus.pending) {
          continue;
        }
        await _processTask(index);
      }
      _showCompletionSnack(onlyRetryFailed: onlyRetryFailed);
    } finally {
      isRunning.value = false;
    }
  }

  Future<void> _processTask(int index) async {
    final task = tasks[index];
    tasks[index] = task.copyWith(
      status: BatchTaskStatus.running,
      clearError: true,
    );
    try {
      switch (operation.value) {
        case BatchOperation.compress:
          await _processCompressTask(index, task.source);
        case BatchOperation.convert:
          await _processConvertTask(index, task.source);
        case BatchOperation.rotate:
          await _processRotateTask(index, task.source);
        case BatchOperation.flip:
          await _processFlipTask(index, task.source);
        case BatchOperation.resize:
          await _processResizeTask(index, task.source);
        case BatchOperation.textWatermark:
          await _processTextWatermarkTask(index, task.source);
        case BatchOperation.imageWatermark:
          await _processImageWatermarkTask(index, task.source);
        case BatchOperation.filter:
          await _processFilterTask(index, task.source);
        case BatchOperation.crop:
          await _processCropTask(index, task.source);
        case BatchOperation.removeExif:
          await _processRemoveExifTask(index, task.source);
        case BatchOperation.grid:
          await _processGridTask(index, task.source);
        case BatchOperation.scanCode:
          await _processScanCodeTask(index, task.source);
        case BatchOperation.base64Encode:
          await _processBase64EncodeTask(index, task.source);
      }
    } on AppException catch (error) {
      tasks[index] = tasks[index].copyWith(
        status: BatchTaskStatus.failed,
        errorMessage: error.message,
      );
      await _historyRepository.recordOperationFailure(
        featureName: operationFeatureName(operation.value),
        inputPath: task.source.path,
        parameters: _historyParameters,
        errorMessage: error.message,
      );
    } finally {
      processedCount.value = tasks.where((task) => task.isTerminal).length;
    }
  }

  Future<void> _processCompressTask(int index, LocalImageFile source) async {
    final compressed = await _imageChannel.compressImage(
      source: source,
      quality: quality.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: compressed.outputPath,
      outputSizeBytes: compressed.outputSizeBytes,
      resultLabel: operationLabel(BatchOperation.compress),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordCompressionSuccess(
      inputPath: source.path,
      outputPath: compressed.outputPath,
      quality: quality.value,
    );
  }

  Future<void> _processConvertTask(int index, LocalImageFile source) async {
    final converted = await _imageChannel.convertImage(
      source: source,
      format: convertFormat.value.value,
      quality: quality.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: converted.outputPath,
      outputSizeBytes: converted.outputSizeBytes,
      resultLabel: converted.format.toUpperCase(),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: converted.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processRotateTask(int index, LocalImageFile source) async {
    final rotated = await _imageChannel.rotateImage(
      source: source,
      degrees: degrees.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: rotated.outputPath,
      outputSizeBytes: rotated.outputSizeBytes,
      resultLabel: '${rotated.degrees}°',
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: rotated.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processFlipTask(int index, LocalImageFile source) async {
    final flipped = await _imageChannel.flipImage(
      source: source,
      direction: flipDirection.value.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: flipped.outputPath,
      outputSizeBytes: flipped.outputSizeBytes,
      resultLabel: flipLabel(flipDirection.value),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: flipped.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processResizeTask(int index, LocalImageFile source) async {
    final dimensions = _resizeDimensionsForSource(source);
    final resized = await _imageChannel.resizeImage(
      source: source,
      width: dimensions.width,
      height: dimensions.height,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: resized.outputPath,
      outputSizeBytes: resized.outputSizeBytes,
      resultLabel: '${resized.width}×${resized.height}',
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: resized.outputPath,
      parameters: _historyParametersForResize(dimensions),
    );
  }

  Future<void> _processTextWatermarkTask(
    int index,
    LocalImageFile source,
  ) async {
    final text = watermarkText.value.trim();
    final watermarked = await _imageChannel.addTextWatermark(
      source: source,
      text: text,
      position: watermarkPosition.value.value,
      fontSize: watermarkFontSize.value,
      opacity: watermarkOpacity.value,
      color: watermarkColor.value.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: watermarked.outputPath,
      outputSizeBytes: watermarked.outputSizeBytes,
      resultLabel: watermarkPositionLabel(watermarkPosition.value),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: watermarked.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processImageWatermarkTask(
    int index,
    LocalImageFile source,
  ) async {
    final watermark = imageWatermark.value;
    if (watermark == null) {
      throw AppException('batch.error.pickWatermarkFirst'.tr);
    }
    final watermarked = await _imageChannel.addImageWatermark(
      source: source,
      watermark: watermark,
      position: imageWatermarkPosition.value.value,
      opacity: imageWatermarkOpacity.value,
      scalePercent: imageWatermarkScale.value,
      rotationDegrees: imageWatermarkRotation.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: watermarked.outputPath,
      outputSizeBytes: watermarked.outputSizeBytes,
      resultLabel: watermarkPositionLabel(imageWatermarkPosition.value),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: watermarked.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processFilterTask(int index, LocalImageFile source) async {
    final filtered = await _imageChannel.applyFilter(
      source: source,
      filter: filter.value.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: filtered.outputPath,
      outputSizeBytes: filtered.outputSizeBytes,
      resultLabel: filterLabel(filter.value),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: filtered.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processCropTask(int index, LocalImageFile source) async {
    final aspectRatio = _cropAspectRatio();
    if (aspectRatio == null) {
      throw AppException('batch.error.invalidCropRatio'.tr);
    }
    final cropped = await _imageChannel.cropImage(
      source: source,
      aspectRatio: aspectRatio,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: cropped.outputPath,
      outputSizeBytes: cropped.outputSizeBytes,
      resultLabel: '${cropped.width}×${cropped.height}',
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: cropped.outputPath,
      parameters: _historyParametersForCrop(aspectRatio),
    );
  }

  Future<void> _processRemoveExifTask(int index, LocalImageFile source) async {
    final cleaned = await _imageChannel.removeExif(source: source);
    tasks[index] = tasks[index].copyWith(
      outputPath: cleaned.outputPath,
      outputSizeBytes: cleaned.outputSizeBytes,
      resultLabel: 'batch.result.exifRemoved'.tr,
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: cleaned.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processGridTask(int index, LocalImageFile source) async {
    final gridImage = await _imageChannel.splitGridImage(
      source: source,
      gridSize: gridSize.value,
    );
    tasks[index] = tasks[index].copyWith(
      outputPath: gridImage.outputDirectory,
      outputSizeBytes: gridImage.outputSizeBytes,
      resultLabel: '${gridImage.gridSize}×${gridImage.gridSize}',
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: gridImage.outputDirectory,
      parameters: _historyParametersForGrid(gridImage.pieceCount),
    );
  }

  Future<void> _processScanCodeTask(int index, LocalImageFile source) async {
    final scan = await _imageChannel.scanBarcodeFromImage(source: source);
    tasks[index] = tasks[index].copyWith(
      outputPath: source.path,
      outputSizeBytes: 0,
      resultLabel: scan.format,
      resultText: _summarizeScanText(scan.text),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: source.path,
      parameters: <String, Object>{
        'operation': operation.value.name,
        'format': scan.format,
        'length': scan.text.length,
        'rawBytesLength': scan.rawBytesLength,
      },
    );
  }

  Future<void> _processBase64EncodeTask(
    int index,
    LocalImageFile source,
  ) async {
    final file = File(source.path);
    if (!await file.exists()) {
      throw AppException('batch.error.imageFileMissing'.tr);
    }
    final sizeBytes = await file.length();
    if (sizeBytes <= 0) {
      throw AppException('batch.error.imageFileEmpty'.tr);
    }
    if (sizeBytes > _maxBase64InputBytes) {
      throw AppException('batch.error.base64FileTooLarge'.tr);
    }

    final bytes = await file.readAsBytes();
    final text = base64Encode(bytes);
    final output = await _createBase64TextFile(source.name);
    await output.writeAsString(text, encoding: utf8, flush: true);
    final outputSizeBytes = await output.length();
    tasks[index] = tasks[index].copyWith(
      outputPath: output.path,
      outputSizeBytes: outputSizeBytes,
      resultLabel: 'TXT',
      resultText: _formatTextLength(text.length),
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operationFeatureName(operation.value),
      inputPath: source.path,
      outputPath: output.path,
      parameters: <String, Object>{
        'operation': operation.value.name,
        'mode': 'encode',
        'length': text.length,
        'mimeType': source.mimeType,
        'saveRule': await _defaultSaveRule(),
      },
    );
  }

  void _markPendingAsPaused() {
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].status == BatchTaskStatus.pending) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.paused);
      }
    }
  }

  void _restorePausedToPending() {
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].status == BatchTaskStatus.paused) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.pending);
      }
    }
  }

  void _markPendingAsCanceled() {
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].status == BatchTaskStatus.pending ||
          tasks[index].status == BatchTaskStatus.paused) {
        tasks[index] = tasks[index].copyWith(status: BatchTaskStatus.canceled);
      }
    }
  }

  void _showCompletionSnack({required bool onlyRetryFailed}) {
    if (tasks.isEmpty || isPaused.value) {
      return;
    }
    final success = successCount;
    final failed = failedCount;
    final canceled = canceledCount;
    final title = onlyRetryFailed
        ? 'batch.completion.retryTitle'.tr
        : 'batch.completion.title'.trParams({
            'operation': operationLabel(operation.value),
          });
    showLatestSnackbar(
      title,
      'batch.completion.message'.trParams({
        'success': success.toString(),
        'failed': failed.toString(),
        'canceled': canceled.toString(),
      }),
    );
  }

  void _resetTasksForCurrentSelection() {
    tasks.assignAll(
      selectedImages.map((image) => BatchImageTask(source: image)),
    );
  }

  double get progress {
    if (tasks.isEmpty) {
      return 0;
    }
    return processedCount.value / tasks.length;
  }

  int get successCount =>
      tasks.where((task) => task.status == BatchTaskStatus.success).length;

  int get failedCount =>
      tasks.where((task) => task.status == BatchTaskStatus.failed).length;

  int get canceledCount =>
      tasks.where((task) => task.status == BatchTaskStatus.canceled).length;

  int get pausedCount =>
      tasks.where((task) => task.status == BatchTaskStatus.paused).length;

  int get totalSizeBytes =>
      selectedImages.fold<int>(0, (sum, image) => sum + image.sizeBytes);

  Map<String, Object> get _historyParameters {
    final parameters = <String, Object>{'operation': operation.value.name};
    switch (operation.value) {
      case BatchOperation.compress:
        parameters['quality'] = quality.value;
      case BatchOperation.convert:
        parameters['quality'] = quality.value;
        parameters['format'] = convertFormat.value.value;
      case BatchOperation.rotate:
        parameters['degrees'] = degrees.value;
      case BatchOperation.flip:
        parameters['direction'] = flipDirection.value.value;
      case BatchOperation.resize:
        parameters.addAll(<String, Object>{
          'mode': resizeMode.value.value,
          'percent': resizePercent.value,
          'width': resizeWidth.value,
          'height': resizeHeight.value,
        });
      case BatchOperation.textWatermark:
        parameters.addAll(<String, Object>{
          'text': watermarkText.value.trim(),
          'position': watermarkPosition.value.value,
          'fontSize': watermarkFontSize.value,
          'opacity': watermarkOpacity.value,
          'color': watermarkColor.value.value,
        });
      case BatchOperation.imageWatermark:
        parameters.addAll(<String, Object>{
          'watermarkPath': imageWatermark.value?.path ?? '',
          'position': imageWatermarkPosition.value.value,
          'opacity': imageWatermarkOpacity.value,
          'scalePercent': imageWatermarkScale.value,
          'rotationDegrees': imageWatermarkRotation.value,
        });
      case BatchOperation.filter:
        parameters['filter'] = filter.value.value;
      case BatchOperation.crop:
        parameters.addAll(<String, Object>{
          'preset': cropPreset.value.name,
          'aspectRatio': _cropAspectRatio() ?? cropPreset.value.aspectRatio,
        });
      case BatchOperation.removeExif:
        parameters['mode'] = 'removeExif';
      case BatchOperation.grid:
        parameters.addAll(<String, Object>{
          'gridSize': gridSize.value,
          'pieceCount': gridSize.value * gridSize.value,
        });
      case BatchOperation.scanCode:
        parameters['mode'] = 'scan_image';
      case BatchOperation.base64Encode:
        parameters.addAll(<String, Object>{
          'mode': 'encode',
          'maxInputBytes': _maxBase64InputBytes,
        });
    }
    return parameters;
  }

  Map<String, Object> _historyParametersForResize(
    _BatchResizeDimensions dimensions,
  ) {
    return <String, Object>{
      'operation': operation.value.name,
      'mode': resizeMode.value.value,
      'percent': resizePercent.value,
      'width': dimensions.width,
      'height': dimensions.height,
    };
  }

  Map<String, Object> _historyParametersForCrop(double aspectRatio) {
    return <String, Object>{
      'operation': operation.value.name,
      'preset': cropPreset.value.name,
      'aspectRatio': aspectRatio,
    };
  }

  Map<String, Object> _historyParametersForGrid(int pieceCount) {
    return <String, Object>{
      'operation': operation.value.name,
      'gridSize': gridSize.value,
      'pieceCount': pieceCount,
    };
  }

  String operationLabel(BatchOperation value) => value.labelKey.tr;

  String operationFeatureName(BatchOperation value) => value.featureKey.tr;

  String flipLabel(BatchFlipDirection value) => value.labelKey.tr;

  String resizeModeLabel(BatchResizeMode value) => value.labelKey.tr;

  String watermarkPositionLabel(BatchWatermarkPosition value) =>
      value.labelKey.tr;

  String watermarkColorLabel(BatchWatermarkColor value) => value.labelKey.tr;

  String filterLabel(BatchFilterType value) => value.labelKey.tr;

  String cropPresetLabel(BatchCropPreset value) => value.labelKey.tr;

  String cropPresetRatioLabel(BatchCropPreset value) =>
      value == BatchCropPreset.custom ? value.ratioText.tr : value.ratioText;

  String taskStatusLabel(BatchTaskStatus value) => value.labelKey.tr;

  String qualityHint() {
    if (operation.value == BatchOperation.compress) {
      return 'batch.hint.compress'.tr;
    }
    if (operation.value == BatchOperation.rotate) {
      return 'batch.hint.rotate'.tr;
    }
    if (operation.value == BatchOperation.flip) {
      return 'batch.hint.flip'.tr;
    }
    if (operation.value == BatchOperation.resize) {
      return switch (resizeMode.value) {
        BatchResizeMode.percent => 'batch.hint.resizePercent'.tr,
        BatchResizeMode.exact => 'batch.hint.resizeExact'.tr,
      };
    }
    if (operation.value == BatchOperation.textWatermark) {
      return 'batch.hint.textWatermark'.tr;
    }
    if (operation.value == BatchOperation.imageWatermark) {
      return 'batch.hint.imageWatermark'.tr;
    }
    if (operation.value == BatchOperation.filter) {
      return 'batch.hint.filter'.tr;
    }
    if (operation.value == BatchOperation.crop) {
      return 'batch.hint.crop'.tr;
    }
    if (operation.value == BatchOperation.removeExif) {
      return 'batch.hint.removeExif'.tr;
    }
    if (operation.value == BatchOperation.grid) {
      return 'batch.hint.grid'.tr;
    }
    if (operation.value == BatchOperation.scanCode) {
      return 'batch.hint.scanCode'.tr;
    }
    if (operation.value == BatchOperation.base64Encode) {
      return 'batch.hint.base64Encode'.tr;
    }
    return switch (convertFormat.value) {
      BatchConvertFormat.jpg ||
      BatchConvertFormat.webp => 'batch.hint.convertLossy'.tr,
      BatchConvertFormat.png ||
      BatchConvertFormat.bmp => 'batch.hint.convertLossless'.tr,
    };
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

  void _showError(String message) {
    showLatestSnackbar('batch.error.title'.tr, message);
  }

  BatchConvertFormat _batchConvertFormatForValue(String value) {
    final normalized = value.trim().toLowerCase();
    return BatchConvertFormat.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => BatchConvertFormat.jpg,
    );
  }

  String _summarizeScanText(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return 'batch.result.noScanText'.tr;
    }
    return normalized.length > 60
        ? '${normalized.substring(0, 60)}...'
        : normalized;
  }

  Future<File> _createBase64TextFile(String sourceName) async {
    final root = await getTemporaryDirectory();
    final saveRule = await _defaultSaveRule();
    final directory = Directory(
      saveRule == 'feature_folder'
          ? '${root.path}/batch_base64_texts/base64'
          : '${root.path}/batch_base64_texts',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _safeFileStem(sourceName);
    final fileName = switch (saveRule) {
      'source_name' => safeName,
      'feature_folder' => '${safeName}_$timestamp',
      _ => 'base64_$timestamp',
    };
    return _availableTextFile(directory, fileName);
  }

  Future<String> _defaultSaveRule() async {
    try {
      return await _settingsRepository.getDefaultSaveRule();
    } catch (_) {
      return 'timestamp';
    }
  }

  Future<File> _availableTextFile(Directory directory, String fileName) async {
    var output = File('${directory.path}/$fileName.txt');
    if (!await output.exists()) {
      return output;
    }
    for (var index = 1; index <= 999; index++) {
      output = File('${directory.path}/${fileName}_$index.txt');
      if (!await output.exists()) {
        return output;
      }
    }
    throw AppException('batch.error.fileNameConflict'.tr);
  }

  String _safeFileStem(String name) {
    final stem = name.trim().replaceFirst(RegExp(r'\.[^.]+$'), '');
    final sanitized = stem.replaceAll(
      RegExp(r'[^A-Za-z0-9_\-\u4e00-\u9fa5]+'),
      '_',
    );
    if (sanitized.isEmpty) {
      return 'image_base64';
    }
    return sanitized.length > 48 ? sanitized.substring(0, 48) : sanitized;
  }

  String _formatTextLength(int length) {
    if (length < 1000) {
      return 'batch.result.textLength'.trParams({'length': length.toString()});
    }
    return 'batch.result.textLengthK'.trParams({
      'lengthK': (length / 1000).toStringAsFixed(1),
    });
  }

  bool _hasValidResizeSettings() {
    if (resizeMode.value == BatchResizeMode.percent) {
      if (resizePercent.value < 10 || resizePercent.value > 300) {
        _showError('batch.error.resizePercentRange'.tr);
        return false;
      }
      if (!selectedImages.every((image) => image.hasValidDimensions)) {
        _showError('batch.error.resizePercentNeedsDimensions'.tr);
        return false;
      }
      return true;
    }
    if (resizeWidth.value < _minResizeDimension ||
        resizeHeight.value < _minResizeDimension) {
      _showError('batch.error.resizePositive'.tr);
      return false;
    }
    if (resizeWidth.value > _maxResizeDimension ||
        resizeHeight.value > _maxResizeDimension) {
      _showError(
        'batch.error.resizeMaxDimension'.trParams({
          'max': _maxResizeDimension.toString(),
        }),
      );
      return false;
    }
    return true;
  }

  bool _hasValidWatermarkSettings() {
    final text = watermarkText.value.trim();
    if (text.isEmpty) {
      _showError('batch.error.watermarkTextRequired'.tr);
      return false;
    }
    if (text.length > 80) {
      _showError('batch.error.watermarkTextTooLong'.tr);
      return false;
    }
    if (watermarkFontSize.value < 12 || watermarkFontSize.value > 160) {
      _showError('batch.error.fontSizeRange'.tr);
      return false;
    }
    if (watermarkOpacity.value < 10 || watermarkOpacity.value > 100) {
      _showError('batch.error.opacityRange'.tr);
      return false;
    }
    return true;
  }

  bool _hasValidImageWatermarkSettings() {
    final watermark = imageWatermark.value;
    if (watermark == null) {
      _showError('batch.error.pickWatermarkFirst'.tr);
      return false;
    }
    if (imageWatermarkOpacity.value < 10 || imageWatermarkOpacity.value > 100) {
      _showError('batch.error.opacityRange'.tr);
      return false;
    }
    if (imageWatermarkScale.value < 5 || imageWatermarkScale.value > 100) {
      _showError('batch.error.imageWatermarkScaleRange'.tr);
      return false;
    }
    if (imageWatermarkRotation.value < -180 ||
        imageWatermarkRotation.value > 180) {
      _showError('batch.error.imageWatermarkRotationRange'.tr);
      return false;
    }
    return true;
  }

  double? _cropAspectRatio() {
    if (cropPreset.value != BatchCropPreset.custom) {
      return cropPreset.value.aspectRatio;
    }
    final width = cropRatioWidth.value;
    final height = cropRatioHeight.value;
    if (width <= 0 || height <= 0) {
      _showError('batch.error.cropRatioPositive'.tr);
      return null;
    }
    final ratio = width / height;
    if (ratio < 0.1 || ratio > 10) {
      _showError('batch.error.cropRatioRange'.tr);
      return null;
    }
    return ratio;
  }

  _BatchResizeDimensions _resizeDimensionsForSource(LocalImageFile source) {
    if (resizeMode.value == BatchResizeMode.exact ||
        !source.hasValidDimensions) {
      return _BatchResizeDimensions(
        width: resizeWidth.value,
        height: resizeHeight.value,
      );
    }
    return _BatchResizeDimensions(
      width: _scaleResizeDimension(source.width, resizePercent.value),
      height: _scaleResizeDimension(source.height, resizePercent.value),
    );
  }

  int _scaleResizeDimension(int value, int percent) {
    return (value * percent / 100).round().clamp(
      _minResizeDimension,
      _maxResizeDimension,
    );
  }
}

class _BatchResizeDimensions {
  const _BatchResizeDimensions({required this.width, required this.height});

  final int width;
  final int height;
}
