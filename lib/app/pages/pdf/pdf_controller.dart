import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../exceptions/app_exception.dart';
import '../../models/local_image_file.dart';
import '../../models/pdf_document_file.dart';
import '../../models/pdf_image_file.dart';
import '../../models/pdf_page_image_file.dart';
import '../../models/pdf_pages_image_export.dart';
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
  portrait(labelKey: 'pdf.orientation.portrait', value: 'portrait'),
  landscape(labelKey: 'pdf.orientation.landscape', value: 'landscape');

  const PdfOrientation({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

/// PDF 工具控制器，负责图片转 PDF、指定页面和全部页面导出图片。
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
  final allPagesResult = Rxn<PdfPagesImageExport>();
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
        _showError(
          'pdf.error.tooManyImages'.trParams({
            'max': LocalImageChannel.maxPdfImages.toString(),
          }),
        );
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
      _showError('pdf.error.recentFileFailed'.tr);
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
      allPagesResult.value = null;
      if (pageNumberController.text.trim().isEmpty) {
        pageNumberController.text = '1';
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('pdf.error.pickPdfFailed'.tr);
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
      _showError('pdf.error.pickImagesFirst'.tr);
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
        featureName: 'pdf.feature.imagesToPdf'.tr,
        inputPath: inputPath,
        outputPath: pdf.outputPath,
        parameters: _historyParameters(),
      );
      showLatestSnackbar(
        'pdf.success.created.title'.tr,
        'pdf.success.created.message'.tr,
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'pdf.feature.imagesToPdf'.tr,
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
      _showError('pdf.error.pickPdfFirst'.tr);
      return;
    }
    final pageNumber = int.tryParse(pageNumberController.text.trim());
    if (pageNumber == null || pageNumber < 1) {
      _showError('pdf.error.invalidPageNumber'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final image = await _imageChannel.exportPdfPageAsImage(
        source: pdf,
        pageNumber: pageNumber,
      );
      pageImageResult.value = image;
      allPagesResult.value = null;
      await _historyRepository.recordOperationSuccess(
        featureName: 'pdf.feature.pageToImage'.tr,
        inputPath: pdf.path,
        outputPath: image.outputPath,
        parameters: <String, Object>{
          'pageNumber': image.pageNumber,
          'pageCount': image.pageCount,
        },
      );
      showLatestSnackbar(
        'pdf.success.pageExported.title'.tr,
        'pdf.success.pageExported.message'.trParams({
          'page': image.pageNumber.toString(),
        }),
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'pdf.feature.pageToImage'.tr,
        inputPath: pdf.path,
        parameters: <String, Object>{'pageNumber': pageNumber},
        errorMessage: error.message,
      );
      _showError(error.message);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> exportAllPdfPages() async {
    if (isBusy.value) {
      return;
    }
    final pdf = selectedPdf.value;
    if (pdf == null) {
      _showError('pdf.error.pickPdfFirst'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final export = await _imageChannel.exportPdfAllPagesAsImages(source: pdf);
      allPagesResult.value = export;
      pageImageResult.value = null;
      await _historyRepository.recordOperationSuccess(
        featureName: 'pdf.feature.allPagesToImages'.tr,
        inputPath: pdf.path,
        outputPath: export.outputDirectory,
        parameters: <String, Object>{
          'pageCount': export.pageCount,
          'outputCount': export.outputPaths.length,
        },
      );
      showLatestSnackbar(
        'pdf.success.allPagesExported.title'.tr,
        'pdf.success.allPagesExported.message'.trParams({
          'count': export.pageCount.toString(),
        }),
      );
    } on AppException catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'pdf.feature.allPagesToImages'.tr,
        inputPath: pdf.path,
        parameters: const <String, Object>{'mode': 'all_pages'},
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

  String orientationLabel(String value) {
    return PdfOrientation.values
        .firstWhere(
          (item) => item.value == value,
          orElse: () => orientation.value,
        )
        .labelKey
        .tr;
  }

  Map<String, Object> _historyParameters() {
    return <String, Object>{
      'pageSize': pageSize.value.value,
      'orientation': orientation.value.value,
      'count': selectedImages.length,
    };
  }

  void _showError(String message) {
    showLatestSnackbar('pdf.error.title'.tr, message);
  }
}
