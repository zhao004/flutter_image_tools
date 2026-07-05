import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/models/local_image_file.dart';
import '../../core/models/pdf_document_file.dart';
import '../../core/models/pdf_image_file.dart';
import '../../core/models/pdf_page_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';

enum PdfPageSize {
  a4(label: 'A4', value: 'a4'),
  a3(label: 'A3', value: 'a3');

  const PdfPageSize({required this.label, required this.value});

  final String label;
  final String value;
}

enum PdfOrientation {
  portrait(label: '竖版', value: 'portrait'),
  landscape(label: '横版', value: 'landscape');

  const PdfOrientation({required this.label, required this.value});

  final String label;
  final String value;
}

/// PDF 工具控制器，负责图片转 PDF 和 PDF 指定页面导出图片。
///
/// 异常策略：Dart 层限制图片数量和页面参数，Android 层负责文件存在性、
/// 图片解码、PDF 读取和文件写入校验；失败写入历史记录，便于追踪输入组合。
class PdfController extends GetxController {
  PdfController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImages = <LocalImageFile>[].obs;
  final result = Rxn<PdfImageFile>();
  final selectedPdf = Rxn<PdfDocumentFile>();
  final pageImageResult = Rxn<PdfPageImageFile>();
  final pageSize = PdfPageSize.a4.obs;
  final orientation = PdfOrientation.portrait.obs;
  final isBusy = false.obs;
  final pageNumberController = TextEditingController(text: '1');

  @override
  void onClose() {
    pageNumberController.dispose();
    super.onClose();
  }

  Future<void> pickImages() async {
    if (isBusy.value) {
      return;
    }
    try {
      final images = await _imageChannel.pickMultipleImages();
      if (images.isEmpty) {
        return;
      }
      if (images.length > LocalImageChannel.maxPdfImages) {
        _showError('单次最多转换 50 张图片');
        return;
      }
      selectedImages.assignAll(images);
      result.value = null;
      for (final image in images) {
        await _recentFilesRepository.recordImage(image);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('记录最近文件失败，请重试');
    }
  }

  Future<void> pickPdf() async {
    if (isBusy.value) {
      return;
    }
    try {
      final pdf = await _imageChannel.pickSinglePdf();
      if (pdf == null) {
        return;
      }
      selectedPdf.value = pdf;
      pageImageResult.value = null;
      if (pageNumberController.text.trim().isEmpty) {
        pageNumberController.text = '1';
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('选择 PDF 失败，请重试');
    }
  }

  void setPageSize(PdfPageSize value) {
    pageSize.value = value;
  }

  void setOrientation(PdfOrientation value) {
    orientation.value = value;
  }

  Future<void> createPdf() async {
    if (isBusy.value) {
      return;
    }
    if (selectedImages.isEmpty) {
      _showError('请先选择图片');
      return;
    }

    isBusy.value = true;
    final inputPath = selectedImages.map((image) => image.path).join('|');
    try {
      final pdf = await _imageChannel.imagesToPdf(
        sources: selectedImages.toList(growable: false),
        pageSize: pageSize.value.value,
        orientation: orientation.value.value,
      );
      result.value = pdf;
      await _historyRepository.recordOperationSuccess(
        featureName: '图片转 PDF',
        inputPath: inputPath,
        outputPath: pdf.outputPath,
        parameters: _historyParameters(),
      );
      Get.snackbar('PDF 已生成', '文件已导出到应用缓存目录');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: '图片转 PDF',
        inputPath: inputPath,
        parameters: _historyParameters(),
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> exportPdfPage() async {
    if (isBusy.value) {
      return;
    }
    final pdf = selectedPdf.value;
    if (pdf == null) {
      _showError('请先选择 PDF 文件');
      return;
    }
    final pageNumber = int.tryParse(pageNumberController.text.trim());
    if (pageNumber == null || pageNumber < 1) {
      _showError('页码必须是大于 0 的整数');
      return;
    }

    isBusy.value = true;
    try {
      final image = await _imageChannel.exportPdfPageAsImage(
        source: pdf,
        pageNumber: pageNumber,
      );
      pageImageResult.value = image;
      await _historyRepository.recordOperationSuccess(
        featureName: 'PDF 转图片',
        inputPath: pdf.path,
        outputPath: image.outputPath,
        parameters: <String, Object>{
          'pageNumber': image.pageNumber,
          'pageCount': image.pageCount,
        },
      );
      Get.snackbar('页面已导出', 'PDF 第 ${image.pageNumber} 页已导出为 PNG');
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'PDF 转图片',
        inputPath: pdf.path,
        parameters: <String, Object>{'pageNumber': pageNumber},
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
  }

  int get totalSizeBytes =>
      selectedImages.fold<int>(0, (sum, image) => sum + image.sizeBytes);

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

  Map<String, Object> _historyParameters() {
    return <String, Object>{
      'pageSize': pageSize.value.value,
      'orientation': orientation.value.value,
      'count': selectedImages.length,
    };
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
