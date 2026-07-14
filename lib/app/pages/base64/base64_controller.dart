import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/base64_image_result.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';
import '../../services/base64_processing_service.dart';

enum Base64Mode { encode, decode }

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
  final mode = Base64Mode.encode.obs;
  final isBusy = false.obs;
  final inputController = TextEditingController();
  String _base64Text = '';

  String get base64Preview => Base64ProcessingService.buildPreview(_base64Text);

  void setMode(Base64Mode value) {
    mode.value = value;
  }

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
      final output = await Base64ProcessingService.encodeFile(
        path: source.path,
        maxInputBytes: maxInputBytes,
      );
      final text = output.text;
      _base64Text = text;
      encodedResult.value = Base64ImageResult(
        source: source,
        outputPath: source.path,
        outputSizeBytes: output.sourceSizeBytes,
        base64Length: text.length,
        mimeType: source.mimeType,
      );
      await _historyRepository.recordOperationSuccess(
        featureName: 'Base64',
        inputPath: source.path,
        outputPath: source.path,
        parameters: <String, Object>{'mode': 'encode', 'length': text.length},
      );
      showLatestSnackbar(
        'base64.encode.success.title'.tr,
        'base64.encode.success.message'.tr,
      );
    } on FileSystemException catch (error) {
      final message = error.message.contains('为空')
          ? 'base64.error.fileEmpty'.tr
          : 'base64.error.fileMissing'.tr;
      await _historyRepository.recordOperationFailure(
        featureName: 'Base64',
        inputPath: source.path,
        parameters: const <String, Object>{'mode': 'encode'},
        errorMessage: message,
      );
      _showError(message);
    } on RangeError {
      await _historyRepository.recordOperationFailure(
        featureName: 'Base64',
        inputPath: source.path,
        parameters: const <String, Object>{'mode': 'encode'},
        errorMessage: 'base64.error.fileTooLarge'.tr,
      );
      _showError('base64.error.fileTooLarge'.tr);
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
    final text = _base64Text;
    if (text.isEmpty) {
      _showError('base64.error.noCopyText'.tr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    showLatestSnackbar(
      'base64.copy.success.title'.tr,
      'base64.copy.success.message'.tr,
    );
  }

  Future<void> exportBase64Text() async {
    if (isBusy.value) {
      return;
    }
    final text = _base64Text;
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
      final outputSize = await Base64ProcessingService.writeTextFile(
        text: text,
        outputPath: output.path,
      );
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
        outputSizeBytes: outputSize,
        base64Length: text.length,
        mimeType: 'text/plain',
      );
      showLatestSnackbar(
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
    final rawText = inputController.text;
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
      final root = await getTemporaryDirectory();
      final decoded = await Base64ProcessingService.decodeToImage(
        rawText: rawText,
        outputDirectory: '${root.path}/base64_images',
        maxBase64Chars: maxBase64Chars,
      );
      outputPath = decoded.outputPath;
      await _imageChannel.saveImageToGallery(decoded.outputPath);
      decodedResult.value = Base64ImageResult(
        outputPath: decoded.outputPath,
        outputSizeBytes: decoded.outputSizeBytes,
        base64Length: decoded.base64Length,
        mimeType: decoded.mimeType,
      );
      await _historyRepository.recordOperationSuccess(
        featureName: 'Base64',
        inputPath: 'base64.history.inputText'.tr,
        outputPath: decoded.outputPath,
        parameters: <String, Object>{
          'mode': 'decode',
          'mimeType': decoded.mimeType,
          'length': decoded.base64Length,
        },
      );
      showLatestSnackbar(
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
    showLatestSnackbar('base64.error.title'.tr, message);
  }
}
