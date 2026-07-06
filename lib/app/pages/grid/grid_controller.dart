import 'dart:ui';

import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/grid_image_file.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// 九宫格切图控制器，管理选图、可拖动网格、执行状态和导出结果。
///
/// 设计意图：页面只负责把手势转换成画布坐标，控制器统一维护网格区域，
/// 并把当前区域转换为图片比例参数传给原生层。异常策略是在 Dart 与
/// Android 双层校验输入，失败时写入历史记录，便于追踪参数和原因。
class GridController extends GetxController {
  GridController({
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
  final result = Rxn<GridImageFile>();
  final gridSize = 3.obs;
  final gridScale = 0.78.obs;
  final gridOffset = Offset.zero.obs;
  final canvasSize = Size.zero.obs;
  final isBusy = false.obs;

  static const double minGridScale = 0.35;
  static const double maxGridScale = 1;

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
      resetGridPosition();
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('grid.error.recentFileFailed'.tr);
    }
  }

  void setGridSize(int value) {
    if (value < LocalImageChannel.minGridSize ||
        value > LocalImageChannel.maxGridSize) {
      _showError('grid.error.invalidSize'.tr);
      return;
    }
    gridSize.value = value;
  }

  void setGridScale(double value, Size canvasSize) {
    if (!_isValidCanvas(canvasSize)) {
      gridScale.value = value.clamp(minGridScale, maxGridScale).toDouble();
      gridOffset.value = Offset.zero;
      return;
    }
    gridScale.value = value.clamp(minGridScale, maxGridScale).toDouble();
    _clampGridOffset(canvasSize);
  }

  void updateCanvasSize(Size value) {
    if (!_isValidCanvas(value)) {
      canvasSize.value = Size.zero;
      return;
    }
    canvasSize.value = value;
    _clampGridOffset(value);
  }

  void moveGrid(Offset delta, Size canvasSize) {
    if (!_isValidCanvas(canvasSize) || delta == Offset.zero) {
      return;
    }
    gridOffset.value += delta;
    _clampGridOffset(canvasSize);
  }

  void resetGridPosition() {
    gridOffset.value = Offset.zero;
  }

  Rect gridRectFor(Size canvasSize) {
    if (!_isValidCanvas(canvasSize)) {
      return Rect.zero;
    }
    final side = _gridSide(canvasSize);
    final centeredLeft = (canvasSize.width - side) / 2;
    final centeredTop = (canvasSize.height - side) / 2;
    final rect = Rect.fromLTWH(
      centeredLeft + gridOffset.value.dx,
      centeredTop + gridOffset.value.dy,
      side,
      side,
    );
    return _clampRect(rect, canvasSize);
  }

  Future<void> splitImage() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('grid.error.pickImageFirst'.tr);
      return;
    }
    final currentCanvasSize = canvasSize.value;
    if (!_isValidCanvas(currentCanvasSize)) {
      _showError('grid.error.invalidCropArea'.tr);
      return;
    }

    final cropRect = gridRectFor(currentCanvasSize);
    if (cropRect.isEmpty || cropRect.width <= 0 || cropRect.height <= 0) {
      _showError('grid.error.invalidCropArea'.tr);
      return;
    }

    isBusy.value = true;
    final currentGridSize = gridSize.value;
    final cropLeftRatio = cropRect.left / currentCanvasSize.width;
    final cropTopRatio = cropRect.top / currentCanvasSize.height;
    final cropSizeRatio =
        cropRect.width /
        _shortestSide(currentCanvasSize).clamp(1.0, double.infinity);
    try {
      final gridImage = await _imageChannel.splitGridImage(
        source: source,
        gridSize: currentGridSize,
        cropLeftRatio: cropLeftRatio,
        cropTopRatio: cropTopRatio,
        cropSizeRatio: cropSizeRatio,
      );
      result.value = gridImage;
      await _historyRepository.recordOperationSuccess(
        featureName: 'grid.featureName'.tr,
        inputPath: source.path,
        outputPath: gridImage.outputDirectory,
        parameters: <String, Object>{
          'gridSize': currentGridSize,
          'pieceCount': gridImage.pieceCount,
          'cropLeftRatio': cropLeftRatio,
          'cropTopRatio': cropTopRatio,
          'cropSizeRatio': cropSizeRatio,
        },
      );
      showLatestSnackbar(
        'grid.split.success.title'.tr,
        'grid.split.success.message'.trParams({
          'count': '${gridImage.pieceCount}',
        }),
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'grid.featureName'.tr,
        inputPath: source.path,
        parameters: <String, Object>{
          'gridSize': currentGridSize,
          'cropLeftRatio': cropLeftRatio,
          'cropTopRatio': cropTopRatio,
          'cropSizeRatio': cropSizeRatio,
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
      return 'grid.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  void _showError(String message) {
    showLatestSnackbar('grid.error.title'.tr, message);
  }

  bool _isValidCanvas(Size canvasSize) {
    return canvasSize.width.isFinite &&
        canvasSize.height.isFinite &&
        canvasSize.width > 0 &&
        canvasSize.height > 0;
  }

  void _clampGridOffset(Size canvasSize) {
    final rect = gridRectFor(canvasSize);
    final side = _gridSide(canvasSize);
    gridOffset.value = Offset(
      rect.left - (canvasSize.width - side) / 2,
      rect.top - (canvasSize.height - side) / 2,
    );
  }

  Rect _clampRect(Rect rect, Size canvasSize) {
    final left = rect.left.clamp(0.0, canvasSize.width - rect.width).toDouble();
    final top = rect.top.clamp(0.0, canvasSize.height - rect.height).toDouble();
    return Rect.fromLTWH(left, top, rect.width, rect.height);
  }

  double _gridSide(Size canvasSize) {
    return (_shortestSide(canvasSize) * gridScale.value)
        .clamp(1.0, _shortestSide(canvasSize))
        .toDouble();
  }

  double _shortestSide(Size canvasSize) {
    return canvasSize.width < canvasSize.height
        ? canvasSize.width
        : canvasSize.height;
  }
}
