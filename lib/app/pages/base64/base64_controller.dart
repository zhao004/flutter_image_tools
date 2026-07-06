import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../exceptions/app_exception.dart';
import '../../models/base64_image_result.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

/// Base64 控制器，负责图片编码、文本复制、文本导出和 Base64 还原图片。
///
/// 异常策略：编码前限制文件大小，解码前清洗 data URI 并限制文本长度；
/// 所有成功和失败任务写入历史记录，便于后续审计本地处理行为。
class Base64Controller extends GetxController {
  Base64Controller({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  static const int maxInputBytes = 12 * 1024 * 1024;
  static const int maxBase64Chars = 18 * 1024 * 1024;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final encodedResult = Rxn<Base64ImageResult>();
  final decodedResult = Rxn<Base64ImageResult>();
  final base64Text = ''.obs;
  final isBusy = false.obs;
  final inputController = TextEditingController();

  @override
  void onClose() {
    inputController.dispose();
    super.onClose();
  }

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
      encodedResult.value = null;
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('base64.error.recentFileFailed'.tr);
    }
  }

  Future<void> encodeSelectedImage() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('base64.error.pickImageFirst'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final file = File(source.path);
      if (!await file.exists()) {
        throw AppException('base64.error.fileMissing'.tr);
      }
      final sizeBytes = await file.length();
      if (sizeBytes <= 0) {
        throw AppException('base64.error.fileEmpty'.tr);
      }
      if (sizeBytes > maxInputBytes) {
        throw AppException('base64.error.fileTooLarge'.tr);
      }
      final bytes = await file.readAsBytes();
      final text = base64Encode(bytes);
      base64Text.value = text;
      inputController.text = text;
      encodedResult.value = Base64ImageResult(
        source: source,
        outputPath: source.path,
        outputSizeBytes: sizeBytes,
        base64Length: text.length,
        mimeType: source.mimeType,
      );
      await _historyRepository.recordOperationSuccess(
        featureName: 'Base64',
        inputPath: source.path,
        outputPath: source.path,
        parameters: <String, Object>{'mode': 'encode', 'length': text.length},
      );
      Get.snackbar(
        'base64.encode.success.title'.tr,
        'base64.encode.success.message'.tr,
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'Base64',
        inputPath: source.path,
        parameters: const <String, Object>{'mode': 'encode'},
        errorMessage: error.message,
      );
      _showError(error.message);
    } catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'Base64',
        inputPath: source.path,
        parameters: const <String, Object>{'mode': 'encode'},
        errorMessage: 'base64.error.encodeFailedLog'.tr,
      );
      _showError('base64.error.encodeFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> copyBase64Text() async {
    final text = base64Text.value.trim();
    if (text.isEmpty) {
      _showError('base64.error.noCopyText'.tr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'base64.copy.success.title'.tr,
      'base64.copy.success.message'.tr,
    );
  }

  Future<void> exportBase64Text() async {
    if (isBusy.value) {
      return;
    }
    final text = base64Text.value.trim();
    final source = selectedImage.value;
    if (text.isEmpty || source == null) {
      _showError('base64.error.generateTextFirst'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final output = await _createOutputFile(
        directoryName: 'base64_texts',
        prefix: 'image_base64',
        extension: 'txt',
      );
      await output.writeAsString(text, encoding: utf8);
      await _historyRepository.recordOperationSuccess(
        featureName: 'Base64',
        inputPath: source.path,
        outputPath: output.path,
        parameters: <String, Object>{
          'mode': 'export_text',
          'length': text.length,
        },
      );
      encodedResult.value = Base64ImageResult(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        base64Length: text.length,
        mimeType: 'text/plain',
      );
      Get.snackbar(
        'base64.export.success.title'.tr,
        'base64.export.success.message'.tr,
      );
    } catch (_) {
      await _historyRepository.recordOperationFailure(
        featureName: 'Base64',
        inputPath: source.path,
        parameters: const <String, Object>{'mode': 'export_text'},
        errorMessage: 'base64.error.exportFailedLog'.tr,
      );
      _showError('base64.error.exportFailed'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  void updateInputText(String value) {
    inputController.text = value;
  }

  Future<void> decodeInputText() async {
    if (isBusy.value) {
      return;
    }
    final rawText = inputController.text.trim();
    if (rawText.isEmpty) {
      _showError('base64.error.inputRequired'.tr);
      return;
    }
    if (rawText.length > maxBase64Chars) {
      _showError('base64.error.inputTooLong'.tr);
      return;
    }

    isBusy.value = true;
    var outputPath = '';
    try {
      final payload = _parseBase64Payload(rawText);
      final bytes = base64Decode(payload.text);
      if (bytes.isEmpty) {
        throw AppException('base64.error.payloadEmpty'.tr);
      }
      final extension = _extensionForMimeType(payload.mimeType);
      final output = await _createOutputFile(
        directoryName: 'base64_images',
        prefix: 'decoded_base64',
        extension: extension,
      );
      outputPath = output.path;
      await output.writeAsBytes(bytes, flush: true);
      decodedResult.value = Base64ImageResult(
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        base64Length: payload.text.length,
        mimeType: payload.mimeType,
      );
      await _historyRepository.recordOperationSuccess(
        featureName: 'Base64',
        inputPath: 'base64.history.inputText'.tr,
        outputPath: output.path,
        parameters: <String, Object>{
          'mode': 'decode',
          'mimeType': payload.mimeType,
          'length': payload.text.length,
        },
      );
      Get.snackbar(
        'base64.decode.success.title'.tr,
        'base64.decode.success.message'.tr,
      );
    } on FormatException {
      await _recordDecodeFailure(
        'base64.error.invalidFormatLog'.tr,
        outputPath,
      );
      _showError('base64.error.invalidFormat'.tr);
    } on AppException catch (error) {
      await _recordDecodeFailure(error.message, outputPath);
      _showError(error.message);
    } catch (_) {
      await _recordDecodeFailure('base64.error.decodeFailedLog'.tr, outputPath);
      _showError('base64.error.decodeFailed'.tr);
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

  String formatTextLength(int length) {
    if (length < 1000) {
      return 'base64.length.characters'.trParams({'count': '$length'});
    }
    return 'base64.length.kCharacters'.trParams({
      'count': (length / 1000).toStringAsFixed(1),
    });
  }

  Future<File> _createOutputFile({
    required String directoryName,
    required String prefix,
    required String extension,
  }) async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/$directoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${directory.path}/${prefix}_$timestamp.$extension');
  }

  _Base64Payload _parseBase64Payload(String rawText) {
    final normalized = rawText.replaceAll(RegExp(r'\s+'), '');
    if (normalized.startsWith('data:')) {
      final separatorIndex = normalized.indexOf(',');
      if (separatorIndex <= 0) {
        throw AppException('base64.error.dataUriMissing'.tr);
      }
      final header = normalized.substring(0, separatorIndex);
      final data = normalized.substring(separatorIndex + 1);
      final mimeType = header
          .replaceFirst('data:', '')
          .split(';')
          .firstWhere((item) => item.contains('/'), orElse: () => 'image/png');
      return _Base64Payload(text: data, mimeType: mimeType);
    }
    return _Base64Payload(text: normalized, mimeType: 'image/png');
  }

  String _extensionForMimeType(String mimeType) {
    return switch (mimeType.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/bmp' => 'bmp',
      _ => 'png',
    };
  }

  Future<void> _recordDecodeFailure(String message, String outputPath) async {
    await _historyRepository.recordOperationFailure(
      featureName: 'Base64',
      inputPath: 'base64.history.inputText'.tr,
      parameters: <String, Object>{
        'mode': 'decode',
        if (outputPath.isNotEmpty) 'outputPath': outputPath,
      },
      errorMessage: message,
    );
  }

  void _showError(String message) {
    Get.snackbar('base64.error.title'.tr, message);
  }
}

class _Base64Payload {
  const _Base64Payload({required this.text, required this.mimeType});

  final String text;
  final String mimeType;
}
