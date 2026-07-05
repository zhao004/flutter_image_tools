import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/base64_image_result.dart';
import '../../core/models/local_image_file.dart';
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
      _showError('记录最近文件失败，请重试');
    }
  }

  Future<void> encodeSelectedImage() async {
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
      final file = File(source.path);
      if (!await file.exists()) {
        throw const AppException('图片文件不存在，请重新选择');
      }
      final sizeBytes = await file.length();
      if (sizeBytes <= 0) {
        throw const AppException('图片文件为空，无法编码');
      }
      if (sizeBytes > maxInputBytes) {
        throw const AppException('图片超过 12 MB，请先压缩后再转 Base64');
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
      Get.snackbar('编码完成', '已生成 Base64 文本');
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
        errorMessage: '图片编码失败',
      );
      _showError('图片编码失败，请重试');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> copyBase64Text() async {
    final text = base64Text.value.trim();
    if (text.isEmpty) {
      _showError('暂无可复制的 Base64 文本');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar('复制完成', 'Base64 文本已复制到剪贴板');
  }

  Future<void> exportBase64Text() async {
    if (isBusy.value) {
      return;
    }
    final text = base64Text.value.trim();
    final source = selectedImage.value;
    if (text.isEmpty || source == null) {
      _showError('请先生成 Base64 文本');
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
      Get.snackbar('导出完成', 'Base64 文本已导出到应用缓存目录');
    } catch (_) {
      await _historyRepository.recordOperationFailure(
        featureName: 'Base64',
        inputPath: source.path,
        parameters: const <String, Object>{'mode': 'export_text'},
        errorMessage: '导出 Base64 文本失败',
      );
      _showError('导出 Base64 文本失败，请检查存储空间');
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
      _showError('请输入 Base64 文本');
      return;
    }
    if (rawText.length > maxBase64Chars) {
      _showError('Base64 文本过长，请分批处理或使用更小图片');
      return;
    }

    isBusy.value = true;
    var outputPath = '';
    try {
      final payload = _parseBase64Payload(rawText);
      final bytes = base64Decode(payload.text);
      if (bytes.isEmpty) {
        throw const AppException('Base64 内容为空，无法还原图片');
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
        inputPath: 'Base64 文本',
        outputPath: output.path,
        parameters: <String, Object>{
          'mode': 'decode',
          'mimeType': payload.mimeType,
          'length': payload.text.length,
        },
      );
      Get.snackbar('还原完成', '图片已导出到应用缓存目录');
    } on FormatException {
      await _recordDecodeFailure('Base64 文本格式无效', outputPath);
      _showError('Base64 文本格式无效，请检查输入');
    } on AppException catch (error) {
      await _recordDecodeFailure(error.message, outputPath);
      _showError(error.message);
    } catch (_) {
      await _recordDecodeFailure('Base64 还原图片失败', outputPath);
      _showError('Base64 还原图片失败，请重试');
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

  String formatTextLength(int length) {
    if (length < 1000) {
      return '$length 字符';
    }
    return '${(length / 1000).toStringAsFixed(1)}K 字符';
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
        throw const AppException('Data URI 缺少 Base64 内容');
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
      inputPath: 'Base64 文本',
      parameters: <String, Object>{
        'mode': 'decode',
        if (outputPath.isNotEmpty) 'outputPath': outputPath,
      },
      errorMessage: message,
    );
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}

class _Base64Payload {
  const _Base64Payload({required this.text, required this.mimeType});

  final String text;
  final String mimeType;
}
