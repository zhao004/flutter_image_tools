import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/barcode_image_file.dart';
import '../../models/barcode_scan_result.dart';
import '../../models/local_image_file.dart';
import '../../models/qr_code_image_file.dart';
import '../../utils/barcode_generator.dart';
import '../../utils/qr_code_generator.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum QrcodeGenerateMode { qrCode, barcode }

/// 二维码控制器，负责本地生成 QR Code PNG 并记录历史。
///
/// 异常策略：先校验文本和字节长度，二维码矩阵与 PNG 编码全部在 Dart 本地
/// 完成；导出失败写入历史记录，方便用户回溯具体输入。
class QrcodeController extends GetxController {
  QrcodeController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  static const int maxContentBytes = QrCodeGenerator.maxContentBytes;
  static const int maxBarcodeLength = BarcodeGenerator.maxContentLength;
  static const int renderScale = 12;
  static const int quietZone = 4;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final inputController = TextEditingController(text: 'https://example.com');
  final generateMode = QrcodeGenerateMode.qrCode.obs;
  final result = Rxn<QrCodeImageFile>();
  final barcodeResult = Rxn<BarcodeImageFile>();
  final selectedImage = Rxn<LocalImageFile>();
  final scanResult = Rxn<BarcodeScanResult>();
  final isBusy = false.obs;

  void setGenerateMode(QrcodeGenerateMode value) {
    if (generateMode.value == value) {
      return;
    }
    generateMode.value = value;
    result.value = null;
    barcodeResult.value = null;
  }

  Future<void> generateSelectedCode() {
    return switch (generateMode.value) {
      QrcodeGenerateMode.qrCode => generateQrCode(),
      QrcodeGenerateMode.barcode => generateBarcode(),
    };
  }

  @override
  void onClose() {
    inputController.dispose();
    super.onClose();
  }

  Future<void> generateQrCode() async {
    if (isBusy.value) {
      return;
    }
    final content = inputController.text.trim();
    if (content.isEmpty) {
      _showError('qrcode.error.qrContentRequired'.tr);
      return;
    }
    if (utf8.encode(content).length > maxContentBytes) {
      _showError(
        'qrcode.error.qrContentTooLong'.trParams({
          'maxBytes': '$maxContentBytes',
        }),
      );
      return;
    }

    isBusy.value = true;
    final startedInput = _summarizeInput(content);
    try {
      final matrix = QrCodeGenerator.encodeText(content);
      final png = QrCodeGenerator.renderPng(
        matrix,
        scale: renderScale,
        quietZone: quietZone,
      );
      final output = await _createOutputFile();
      await output.writeAsBytes(png, flush: true);
      final pixelSize = (matrix.size + quietZone * 2) * renderScale;
      final qr = QrCodeImageFile(
        content: content,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        version: matrix.version,
        moduleCount: matrix.size,
        pixelSize: pixelSize,
      );
      if (!qr.hasValidOutput) {
        throw const FormatException();
      }
      await _imageChannel.saveImageToGallery(output.path);
      result.value = qr;
      barcodeResult.value = null;
      await _historyRepository.recordOperationSuccess(
        featureName: 'qrcode.feature.qrGenerate'.tr,
        inputPath: startedInput,
        outputPath: output.path,
        parameters: <String, Object>{
          'version': qr.version,
          'moduleCount': qr.moduleCount,
          'pixelSize': qr.pixelSize,
        },
      );
      showLatestSnackbar(
        'qrcode.generate.success.title'.tr,
        'qrcode.generate.qrSuccess.message'.tr,
      );
    } on ArgumentError catch (error) {
      final message = error.message?.toString() ?? 'qrcode.error.qrInvalid'.tr;
      await _recordFailure(startedInput, message);
      _showError(message);
    } catch (_) {
      final message = 'qrcode.error.qrGenerateFailedLog'.tr;
      await _recordFailure(startedInput, message);
      _showError('qrcode.error.qrGenerateFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> generateBarcode() async {
    if (isBusy.value) {
      return;
    }
    final content = inputController.text.trim();
    if (content.isEmpty) {
      _showError('qrcode.error.barcodeContentRequired'.tr);
      return;
    }
    if (content.length > maxBarcodeLength) {
      _showError(
        'qrcode.error.barcodeContentTooLong'.trParams({
          'maxChars': '$maxBarcodeLength',
        }),
      );
      return;
    }
    if (!_isPrintableAscii(content)) {
      _showError('qrcode.error.barcodeAsciiOnly'.tr);
      return;
    }

    isBusy.value = true;
    final startedInput = _summarizeInput(content);
    try {
      final barcode = BarcodeGenerator.renderCode128Png(content);
      final output = await _createOutputFile(prefix: 'barcode');
      await output.writeAsBytes(barcode.png, flush: true);
      final file = BarcodeImageFile(
        content: content,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        format: 'CODE_128',
        pixelWidth: barcode.pixelWidth,
        pixelHeight: barcode.pixelHeight,
      );
      if (!file.hasValidOutput) {
        throw const FormatException();
      }
      await _imageChannel.saveImageToGallery(output.path);
      barcodeResult.value = file;
      result.value = null;
      await _historyRepository.recordOperationSuccess(
        featureName: 'qrcode.feature.barcodeGenerate'.tr,
        inputPath: startedInput,
        outputPath: output.path,
        parameters: <String, Object>{
          'format': file.format,
          'pixelWidth': file.pixelWidth,
          'pixelHeight': file.pixelHeight,
        },
      );
      showLatestSnackbar(
        'qrcode.generate.success.title'.tr,
        'qrcode.generate.barcodeSuccess.message'.tr,
      );
    } on ArgumentError catch (error) {
      final message =
          error.message?.toString() ?? 'qrcode.error.barcodeInvalid'.tr;
      await _recordFailure(
        startedInput,
        message,
        featureName: 'qrcode.feature.barcodeGenerate'.tr,
      );
      _showError(message);
    } catch (_) {
      final message = 'qrcode.error.barcodeGenerateFailedLog'.tr;
      await _recordFailure(
        startedInput,
        message,
        featureName: 'qrcode.feature.barcodeGenerate'.tr,
      );
      _showError('qrcode.error.barcodeGenerateFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> pickAndScanImage() async {
    await scanFromGallery();
  }

  Future<void> scanFromGallery() async {
    await _pickAndScanImage(
      origin: BarcodeScanOrigin.gallery,
      picker: _imageChannel.pickSingleImage,
    );
  }

  Future<void> _pickAndScanImage({
    required BarcodeScanOrigin origin,
    required Future<LocalImageFile?> Function() picker,
  }) async {
    if (isBusy.value) {
      return;
    }

    isBusy.value = true;
    LocalImageFile? image;
    try {
      image = await picker();
      if (image == null) {
        return;
      }
      selectedImage.value = image;
      scanResult.value = null;
      await _recentFilesRepository.recordImage(image);
      final scan = await _imageChannel.scanBarcodeFromImage(
        source: image,
        origin: origin,
      );
      scanResult.value = scan;
      await _historyRepository.recordOperationSuccess(
        featureName: 'qrcode.feature.scan'.tr,
        inputPath: image.path,
        outputPath: image.path,
        parameters: <String, Object>{
          'format': scan.format,
          'length': scan.text.length,
          'rawBytesLength': scan.rawBytesLength,
          'origin': origin.name,
        },
      );
      showLatestSnackbar(
        'qrcode.scan.success.title'.tr,
        'qrcode.scan.success.message'.trParams({'format': scan.format}),
      );
    } on AppException catch (error) {
      if (image != null) {
        await _historyRepository.recordOperationFailure(
          featureName: 'qrcode.feature.scan'.tr,
          inputPath: image.path,
          parameters: <String, Object>{'mode': origin.name},
          errorMessage: error.message,
        );
      }
      _showError(error.message);
    } catch (_) {
      if (image != null) {
        await _historyRepository.recordOperationFailure(
          featureName: 'qrcode.feature.scan'.tr,
          inputPath: image.path,
          parameters: <String, Object>{'mode': origin.name},
          errorMessage: 'qrcode.error.scanFailedLog'.tr,
        );
      }
      _showError('qrcode.error.scanFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> scanFromLiveCamera() async {
    if (isBusy.value) {
      return;
    }
    isBusy.value = true;
    try {
      final scan = await _imageChannel.scanBarcodeFromCamera();
      if (scan == null) {
        return;
      }
      selectedImage.value = null;
      scanResult.value = scan;
      await _historyRepository.recordOperationSuccess(
        featureName: 'qrcode.feature.scan'.tr,
        inputPath: 'qrcode.scan.origin.live'.tr,
        outputPath: '',
        parameters: <String, Object>{
          'format': scan.format,
          'length': scan.text.length,
          'rawBytesLength': scan.rawBytesLength,
          'origin': BarcodeScanOrigin.liveCamera.name,
        },
      );
      showLatestSnackbar(
        'qrcode.scan.success.title'.tr,
        'qrcode.scan.success.message'.trParams({'format': scan.format}),
      );
    } on AppException catch (error) {
      await _recordLiveScanFailure(error.message);
      _showError(error.message);
    } catch (_) {
      await _recordLiveScanFailure('qrcode.error.scanFailedLog'.tr);
      _showError('qrcode.error.scanFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> _recordLiveScanFailure(String message) async {
    await _historyRepository.recordOperationFailure(
      featureName: 'qrcode.feature.scan'.tr,
      inputPath: 'qrcode.scan.origin.live'.tr,
      parameters: const <String, Object>{'mode': 'liveCamera'},
      errorMessage: message,
    );
  }

  Future<void> copyScanText() async {
    final text = scanResult.value?.text.trim() ?? '';
    if (text.isEmpty) {
      _showError('qrcode.error.scanTextEmpty'.tr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    showLatestSnackbar(
      'qrcode.copy.success.title'.tr,
      text.length > 60 ? '${text.substring(0, 60)}...' : text,
    );
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

  Future<File> _createOutputFile({String prefix = 'qrcode'}) async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/qrcode_images');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${directory.path}/${prefix}_$timestamp.png');
  }

  Future<void> _recordFailure(
    String input,
    String message, {
    String? featureName,
  }) async {
    await _historyRepository.recordOperationFailure(
      featureName: featureName ?? 'qrcode.feature.qrGenerate'.tr,
      inputPath: input,
      parameters: const <String, Object>{'mode': 'generate'},
      errorMessage: message,
    );
  }

  String _summarizeInput(String input) {
    return input.length > 80 ? '${input.substring(0, 80)}...' : input;
  }

  bool _isPrintableAscii(String input) {
    for (final codeUnit in input.codeUnits) {
      if (codeUnit < 32 || codeUnit > 126) {
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    showLatestSnackbar('qrcode.error.title'.tr, message);
  }
}
