import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../exceptions/app_exception.dart';
import '../../models/local_image_file.dart';
import '../../models/picked_color_sample.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// 颜色提取控制器，负责选图、解码像素、点击取色和复制颜色值。
///
/// 异常策略：图片读取和像素解码均在控制器内捕获并转换为中文提示；点击坐标
/// 会裁剪到图片边界，避免边缘点击因为浮点误差越界。
class ColorPickerController extends GetxController {
  ColorPickerController({
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
  final sample = Rxn<PickedColorSample>();
  final isBusy = false.obs;

  ui.Image? _decodedImage;
  ByteData? _pixelBytes;

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
      await _loadImagePixels(image);
      selectedImage.value = image;
      sample.value = null;
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('colorPicker.error.readFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> pickColor({
    required double localX,
    required double localY,
    required double displayWidth,
    required double displayHeight,
  }) async {
    final image = selectedImage.value;
    final decoded = _decodedImage;
    final bytes = _pixelBytes;
    if (image == null || decoded == null || bytes == null) {
      _showError('colorPicker.error.pickImageFirst'.tr);
      return;
    }
    if (displayWidth <= 0 || displayHeight <= 0) {
      _showError('colorPicker.error.invalidDisplayArea'.tr);
      return;
    }

    final pixelX = (localX / displayWidth * decoded.width).floor().clamp(
      0,
      decoded.width - 1,
    );
    final pixelY = (localY / displayHeight * decoded.height).floor().clamp(
      0,
      decoded.height - 1,
    );
    final byteOffset = (pixelY * decoded.width + pixelX) * 4;
    if (byteOffset < 0 || byteOffset + 3 >= bytes.lengthInBytes) {
      _showError('colorPicker.error.outOfRange'.tr);
      return;
    }

    final picked = PickedColorSample(
      x: pixelX,
      y: pixelY,
      red: bytes.getUint8(byteOffset),
      green: bytes.getUint8(byteOffset + 1),
      blue: bytes.getUint8(byteOffset + 2),
      alpha: bytes.getUint8(byteOffset + 3),
    );
    sample.value = picked;
    await _recordPickSuccess(image, picked);
  }

  Future<void> copyValue(String value) async {
    if (value.trim().isEmpty) {
      _showError('colorPicker.error.emptyColorValue'.tr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    Get.snackbar('colorPicker.copy.success.title'.tr, value);
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
      return 'colorPicker.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  @override
  void onClose() {
    _decodedImage?.dispose();
    super.onClose();
  }

  Future<void> _loadImagePixels(LocalImageFile image) async {
    if (image.path.trim().isEmpty) {
      throw AppException('colorPicker.error.emptyPath'.tr);
    }
    final file = File(image.path);
    if (!file.existsSync()) {
      throw AppException('colorPicker.error.fileMissing'.tr);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AppException('colorPicker.error.fileEmpty'.tr);
    }

    _decodedImage?.dispose();
    _decodedImage = await _decodeImage(bytes);
    _pixelBytes = await _decodedImage!.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (_pixelBytes == null) {
      throw AppException('colorPicker.error.pixelReadFailed'.tr);
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Future<void> _recordPickSuccess(
    LocalImageFile image,
    PickedColorSample picked,
  ) async {
    try {
      await _historyRepository.recordOperationSuccess(
        featureName: 'colorPicker.featureName'.tr,
        inputPath: image.path,
        outputPath: image.path,
        parameters: <String, Object>{
          'x': picked.x,
          'y': picked.y,
          'rgb': picked.rgbText,
          'hex': picked.hexText,
          'hsv': picked.hsvText,
        },
      );
    } catch (_) {
      // 历史记录失败不影响用户获取颜色，避免数据库问题阻断核心取色流程。
    }
  }

  void _showError(String message) {
    Get.snackbar('colorPicker.error.title'.tr, message);
  }
}
