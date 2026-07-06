import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum BatchOperation {
  compress(label: '批量压缩', featureName: '批量压缩'),
  convert(label: '格式转换', featureName: '批量格式转换'),
  rotate(label: '批量旋转', featureName: '批量旋转'),
  flip(label: '批量翻转', featureName: '批量翻转'),
  resize(label: '尺寸调整', featureName: '批量尺寸调整'),
  textWatermark(label: '文字水印', featureName: '批量文字水印'),
  imageWatermark(label: '图片水印', featureName: '批量图片水印'),
  filter(label: '图片滤镜', featureName: '批量图片滤镜'),
  crop(label: '图片裁剪', featureName: '批量图片裁剪'),
  removeExif(label: '删除 EXIF', featureName: '批量删除 EXIF'),
  grid(label: '九宫格切图', featureName: '批量九宫格切图');

  const BatchOperation({required this.label, required this.featureName});

  final String label;
  final String featureName;
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
  horizontal(label: '水平翻转', value: 'horizontal'),
  vertical(label: '垂直翻转', value: 'vertical');

  const BatchFlipDirection({required this.label, required this.value});

  final String label;
  final String value;
}

enum BatchResizeMode {
  percent(label: '按百分比', value: 'percent'),
  exact(label: '固定宽高', value: 'exact');

  const BatchResizeMode({required this.label, required this.value});

  final String label;
  final String value;
}

enum BatchWatermarkPosition {
  topLeft(label: '左上', value: 'topLeft'),
  topRight(label: '右上', value: 'topRight'),
  bottomLeft(label: '左下', value: 'bottomLeft'),
  bottomRight(label: '右下', value: 'bottomRight'),
  center(label: '居中', value: 'center'),
  tile(label: '平铺', value: 'tile');

  const BatchWatermarkPosition({required this.label, required this.value});

  final String label;
  final String value;
}

enum BatchWatermarkColor {
  white(label: '白色', value: '#FFFFFF'),
  black(label: '黑色', value: '#000000'),
  red(label: '红色', value: '#E53935'),
  yellow(label: '黄色', value: '#FDD835');

  const BatchWatermarkColor({required this.label, required this.value});

  final String label;
  final String value;
}

enum BatchFilterType {
  grayscale(label: '灰度', value: 'grayscale'),
  monochrome(label: '黑白', value: 'monochrome'),
  sepia(label: '怀旧', value: 'sepia'),
  invert(label: '反色', value: 'invert'),
  warm(label: '暖色', value: 'warm'),
  cool(label: '冷色', value: 'cool'),
  hdr(label: 'HDR', value: 'hdr'),
  film(label: '胶片', value: 'film'),
  sharpen(label: '锐化', value: 'sharpen'),
  soften(label: '柔化', value: 'soften');

  const BatchFilterType({required this.label, required this.value});

  final String label;
  final String value;
}

enum BatchCropPreset {
  square(label: '正方形', ratioText: '1:1', aspectRatio: 1),
  landscape16x9(label: '横版', ratioText: '16:9', aspectRatio: 16 / 9),
  landscape4x3(label: '经典', ratioText: '4:3', aspectRatio: 4 / 3),
  portrait9x16(label: '竖版', ratioText: '9:16', aspectRatio: 9 / 16),
  custom(label: '自定义', ratioText: '自定义', aspectRatio: 1);

  const BatchCropPreset({
    required this.label,
    required this.ratioText,
    required this.aspectRatio,
  });

  final String label;
  final String ratioText;
  final double aspectRatio;
}

enum BatchTaskStatus {
  pending(label: '等待'),
  running(label: '处理中'),
  paused(label: '已暂停'),
  success(label: '成功'),
  failed(label: '失败'),
  canceled(label: '已取消');

  const BatchTaskStatus({required this.label});

  final String label;
}

class BatchImageTask {
  const BatchImageTask({
    required this.source,
    this.outputPath = '',
    this.outputSizeBytes = 0,
    this.resultLabel = '',
    this.errorMessage,
    this.status = BatchTaskStatus.pending,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final String resultLabel;
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
    String? errorMessage,
    BatchTaskStatus? status,
    bool clearError = false,
  }) {
    return BatchImageTask(
      source: source,
      outputPath: outputPath ?? this.outputPath,
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
      resultLabel: resultLabel ?? this.resultLabel,
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
  }

  Future<void> _loadDefaultQuality() async {
    try {
      quality.value = await _settingsRepository.getDefaultQuality();
    } catch (_) {
      quality.value = 80;
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
      _showError('记录最近文件失败，请重试');
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
      _showError('记录最近文件失败，请重试');
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
      _showError('网格大小必须在 2 到 5 之间');
      return;
    }
    gridSize.value = value;
  }

  Future<void> startQueue() async {
    if (isRunning.value) {
      return;
    }
    if (selectedImages.isEmpty) {
      _showError('请先选择图片');
      return;
    }
    if (operation.value == BatchOperation.rotate && degrees.value == 0) {
      _showError('旋转角度不能为 0');
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
      _showError('暂无失败任务可重试');
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
      }
    } on AppException catch (error) {
      tasks[index] = tasks[index].copyWith(
        status: BatchTaskStatus.failed,
        errorMessage: error.message,
      );
      await _historyRepository.recordOperationFailure(
        featureName: operation.value.featureName,
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
      resultLabel: '压缩',
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
      featureName: operation.value.featureName,
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
      featureName: operation.value.featureName,
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
      resultLabel: flipDirection.value.label,
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operation.value.featureName,
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
      featureName: operation.value.featureName,
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
      resultLabel: watermarkPosition.value.label,
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operation.value.featureName,
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
      throw const AppException('请先选择水印图片');
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
      resultLabel: imageWatermarkPosition.value.label,
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operation.value.featureName,
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
      resultLabel: filter.value.label,
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operation.value.featureName,
      inputPath: source.path,
      outputPath: filtered.outputPath,
      parameters: _historyParameters,
    );
  }

  Future<void> _processCropTask(int index, LocalImageFile source) async {
    final aspectRatio = _cropAspectRatio();
    if (aspectRatio == null) {
      throw const AppException('裁剪比例无效');
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
      featureName: operation.value.featureName,
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
      resultLabel: 'EXIF 已删除',
      status: BatchTaskStatus.success,
      clearError: true,
    );
    await _historyRepository.recordOperationSuccess(
      featureName: operation.value.featureName,
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
      featureName: operation.value.featureName,
      inputPath: source.path,
      outputPath: gridImage.outputDirectory,
      parameters: _historyParametersForGrid(gridImage.pieceCount),
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
    final title = onlyRetryFailed ? '失败重试完成' : '${operation.value.label}完成';
    Get.snackbar(title, '成功 $success 张，失败 $failed 张，取消 $canceled 张');
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

  String qualityHint() {
    if (operation.value == BatchOperation.compress) {
      return '压缩会按当前质量导出，质量越低文件越小。';
    }
    if (operation.value == BatchOperation.rotate) {
      return '旋转会按当前角度导出新图片，不会覆盖原文件。';
    }
    if (operation.value == BatchOperation.flip) {
      return '翻转会按当前方向导出新图片，不会覆盖原文件。';
    }
    if (operation.value == BatchOperation.resize) {
      return switch (resizeMode.value) {
        BatchResizeMode.percent => '按百分比模式会基于每张图片原始尺寸分别缩放。',
        BatchResizeMode.exact => '固定宽高模式会把所有图片导出为相同目标尺寸。',
      };
    }
    if (operation.value == BatchOperation.textWatermark) {
      return '文字水印会按当前文本、位置、颜色、字号和透明度批量导出新图片。';
    }
    if (operation.value == BatchOperation.imageWatermark) {
      return '图片水印会用同一张水印图按当前位置、透明度、缩放和旋转参数批量导出。';
    }
    if (operation.value == BatchOperation.filter) {
      return '滤镜会按当前类型批量导出新图片，不会覆盖原文件。';
    }
    if (operation.value == BatchOperation.crop) {
      return '裁剪会从每张图片中心保留当前比例区域并导出新图片。';
    }
    if (operation.value == BatchOperation.removeExif) {
      return '删除 EXIF 会重新导出去除元数据的图片副本，不会覆盖原文件。';
    }
    if (operation.value == BatchOperation.grid) {
      return '九宫格切图会为每张图片生成独立切片目录，支持 2×2 到 5×5。';
    }
    return switch (convertFormat.value) {
      BatchConvertFormat.jpg ||
      BatchConvertFormat.webp => 'JPG 和 WebP 会使用导出质量。',
      BatchConvertFormat.png ||
      BatchConvertFormat.bmp => 'PNG 和 BMP 为无损导出，质量参数会被忽略。',
    };
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

  bool _hasValidResizeSettings() {
    if (resizeMode.value == BatchResizeMode.percent) {
      if (resizePercent.value < 10 || resizePercent.value > 300) {
        _showError('缩放比例必须在 10% 到 300% 之间');
        return false;
      }
      if (!selectedImages.every((image) => image.hasValidDimensions)) {
        _showError('按百分比缩放需要所有图片都有有效尺寸');
        return false;
      }
      return true;
    }
    if (resizeWidth.value < _minResizeDimension ||
        resizeHeight.value < _minResizeDimension) {
      _showError('目标宽高必须大于 0');
      return false;
    }
    if (resizeWidth.value > _maxResizeDimension ||
        resizeHeight.value > _maxResizeDimension) {
      _showError('目标宽高不能超过 $_maxResizeDimension 像素');
      return false;
    }
    return true;
  }

  bool _hasValidWatermarkSettings() {
    final text = watermarkText.value.trim();
    if (text.isEmpty) {
      _showError('请输入水印文字');
      return false;
    }
    if (text.length > 80) {
      _showError('水印文字不能超过 80 个字符');
      return false;
    }
    if (watermarkFontSize.value < 12 || watermarkFontSize.value > 160) {
      _showError('字号必须在 12 到 160 之间');
      return false;
    }
    if (watermarkOpacity.value < 10 || watermarkOpacity.value > 100) {
      _showError('透明度必须在 10 到 100 之间');
      return false;
    }
    return true;
  }

  bool _hasValidImageWatermarkSettings() {
    final watermark = imageWatermark.value;
    if (watermark == null) {
      _showError('请先选择水印图片');
      return false;
    }
    if (imageWatermarkOpacity.value < 10 || imageWatermarkOpacity.value > 100) {
      _showError('透明度必须在 10 到 100 之间');
      return false;
    }
    if (imageWatermarkScale.value < 5 || imageWatermarkScale.value > 100) {
      _showError('水印缩放必须在 5% 到 100% 之间');
      return false;
    }
    if (imageWatermarkRotation.value < -180 ||
        imageWatermarkRotation.value > 180) {
      _showError('旋转角度必须在 -180 到 180 之间');
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
      _showError('自定义比例必须大于 0');
      return null;
    }
    final ratio = width / height;
    if (ratio < 0.1 || ratio > 10) {
      _showError('自定义比例必须在 0.1 到 10 之间');
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
