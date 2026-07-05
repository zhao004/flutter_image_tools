import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/qr_code_image_file.dart';
import '../../core/utils/qr_code_generator.dart';
import '../../repositories/operation_history_repository.dart';

/// 二维码控制器，负责本地生成 QR Code PNG 并记录历史。
///
/// 异常策略：先校验文本和字节长度，二维码矩阵与 PNG 编码全部在 Dart 本地
/// 完成；导出失败写入历史记录，方便用户回溯具体输入。
class QrcodeController extends GetxController {
  QrcodeController({required OperationHistoryRepository historyRepository})
    : _historyRepository = historyRepository;

  static const int maxContentBytes = QrCodeGenerator.maxContentBytes;
  static const int renderScale = 12;
  static const int quietZone = 4;

  final OperationHistoryRepository _historyRepository;

  final inputController = TextEditingController(text: 'https://example.com');
  final result = Rxn<QrCodeImageFile>();
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
    final startedInput = content.length > 80
        ? '${content.substring(0, 80)}...'
        : content;
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

  Future<File> _createOutputFile() async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/qrcode_images');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${directory.path}/qrcode_$timestamp.png');
  }

  Future<void> _recordFailure(String input, String message) async {
    await _historyRepository.recordOperationFailure(
      featureName: '二维码生成',
      inputPath: input,
      parameters: const <String, Object>{'mode': 'generate'},
      errorMessage: message,
    );
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
