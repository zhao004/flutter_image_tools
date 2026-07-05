import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/barcode_image_file.dart';
import '../../core/models/barcode_scan_result.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/qr_code_image_file.dart';
import '../../core/utils/barcode_generator.dart';
import '../../core/utils/qr_code_generator.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

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
  final result = Rxn<QrCodeImageFile>();
  final barcodeResult = Rxn<BarcodeImageFile>();
  final selectedImage = Rxn<LocalImageFile>();
  final scanResult = Rxn<BarcodeScanResult>();
  final isBusy = false.obs;

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
      _showError('请输入二维码内容');
      return;
    }
    if (utf8.encode(content).length > maxContentBytes) {
      _showError('内容过长，请控制在 $maxContentBytes 字节以内');
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
        throw const FormatException('二维码输出文件异常');
      }
      result.value = qr;
      barcodeResult.value = null;
      await _historyRepository.recordOperationSuccess(
        featureName: '二维码生成',
        inputPath: startedInput,
        outputPath: output.path,
        parameters: <String, Object>{
          'version': qr.version,
          'moduleCount': qr.moduleCount,
          'pixelSize': qr.pixelSize,
        },
      );
      Get.snackbar('生成完成', '二维码 PNG 已导出到应用缓存目录');
    } on ArgumentError catch (error) {
      await _recordFailure(
        startedInput,
        error.message?.toString() ?? '二维码参数无效',
      );
      _showError(error.message?.toString() ?? '二维码参数无效');
    } catch (_) {
      await _recordFailure(startedInput, '二维码生成失败');
      _showError('二维码生成失败，请重试');
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
      _showError('请输入条形码内容');
      return;
    }
    if (content.length > maxBarcodeLength) {
      _showError('条形码内容不能超过 $maxBarcodeLength 个字符');
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
        throw const FormatException('条形码输出文件异常');
      }
      barcodeResult.value = file;
      result.value = null;
      await _historyRepository.recordOperationSuccess(
        featureName: '条形码生成',
        inputPath: startedInput,
        outputPath: output.path,
        parameters: <String, Object>{
          'format': file.format,
          'pixelWidth': file.pixelWidth,
          'pixelHeight': file.pixelHeight,
        },
      );
      Get.snackbar('生成完成', '条形码 PNG 已导出到应用缓存目录');
    } on ArgumentError catch (error) {
      final message = error.message?.toString() ?? '条形码参数无效';
      await _recordFailure(startedInput, message, featureName: '条形码生成');
      _showError(message);
    } catch (_) {
      await _recordFailure(startedInput, '条形码生成失败', featureName: '条形码生成');
      _showError('条形码生成失败，请重试');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> pickAndScanImage() async {
    if (isBusy.value) {
      return;
    }

    isBusy.value = true;
    LocalImageFile? image;
    try {
      image = await _imageChannel.pickSingleImage();
      if (image == null) {
        return;
      }
      selectedImage.value = image;
      scanResult.value = null;
      await _recentFilesRepository.recordImage(image);
      final scan = await _imageChannel.scanBarcodeFromImage(source: image);
      scanResult.value = scan;
      await _historyRepository.recordOperationSuccess(
        featureName: '二维码识别',
        inputPath: image.path,
        outputPath: image.path,
        parameters: <String, Object>{
          'format': scan.format,
          'length': scan.text.length,
          'rawBytesLength': scan.rawBytesLength,
        },
      );
      Get.snackbar('识别完成', '已识别 ${scan.format} 内容');
    } on AppException catch (error) {
      if (image != null) {
        await _historyRepository.recordOperationFailure(
          featureName: '二维码识别',
          inputPath: image.path,
          parameters: const <String, Object>{'mode': 'scan_image'},
          errorMessage: error.message,
        );
      }
      _showError(error.message);
    } catch (_) {
      if (image != null) {
        await _historyRepository.recordOperationFailure(
          featureName: '二维码识别',
          inputPath: image.path,
          parameters: const <String, Object>{'mode': 'scan_image'},
          errorMessage: '二维码识别失败',
        );
      }
      _showError('二维码识别失败，请重试');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> copyScanText() async {
    final text = scanResult.value?.text.trim() ?? '';
    if (text.isEmpty) {
      _showError('识别内容为空，无法复制');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      '已复制',
      text.length > 60 ? '${text.substring(0, 60)}...' : text,
    );
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
    String featureName = '二维码生成',
  }) async {
    await _historyRepository.recordOperationFailure(
      featureName: featureName,
      inputPath: input,
      parameters: const <String, Object>{'mode': 'generate'},
      errorMessage: message,
    );
  }

  String _summarizeInput(String input) {
    return input.length > 80 ? '${input.substring(0, 80)}...' : input;
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
