import 'package:flutter/services.dart';

import '../core/exceptions/app_exception.dart';
import '../core/models/annotated_image_file.dart';
import '../core/models/barcode_scan_result.dart';
import '../core/models/compressed_gif_file.dart';
import '../core/models/compressed_image_file.dart';
import '../core/models/converted_image_file.dart';
import '../core/models/cropped_image_file.dart';
import '../core/models/exif_cleaned_image_file.dart';
import '../core/models/exif_info.dart';
import '../core/models/filtered_image_file.dart';
import '../core/models/flipped_image_file.dart';
import '../core/models/gif_frames_export.dart';
import '../core/models/gif_image_file.dart';
import '../core/models/grid_image_file.dart';
import '../core/models/image_watermarked_file.dart';
import '../core/models/local_image_file.dart';
import '../core/models/merged_image_file.dart';
import '../core/models/pdf_document_file.dart';
import '../core/models/pdf_image_file.dart';
import '../core/models/pdf_page_image_file.dart';
import '../core/models/pdf_pages_image_export.dart';
import '../core/models/resized_image_file.dart';
import '../core/models/rotated_image_file.dart';
import '../core/models/watermarked_image_file.dart';

/// Android 本地图片能力通道，封装选择图片和压缩图片的原生调用。
///
/// 设计意图：第一阶段不引入额外 Flutter 插件，先用原生平台能力形成离线
/// 闭环；所有 PlatformException 在此转换为 AppException，界面无需感知
/// MethodChannel 细节。
class LocalImageChannel {
  LocalImageChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'image_toolkit/local_image';
  static const int maxResizeDimension = 10000;
  static const int maxMergeImages = 20;
  static const int maxPdfImages = 50;
  static const int maxGifImages = 30;
  static const int minGifDelayMs = 50;
  static const int maxGifDelayMs = 2000;
  static const int minGifFrameStepMs = 50;
  static const int maxGifFrameStepMs = 1000;
  static const int minGifScalePercent = 25;
  static const int maxGifScalePercent = 100;
  static const int minGridSize = 2;
  static const int maxGridSize = 5;
  static const Set<String> supportedFilters = {
    'grayscale',
    'monochrome',
    'sepia',
    'invert',
    'warm',
    'cool',
    'hdr',
    'film',
    'sharpen',
    'soften',
  };
  static const Set<String> supportedConvertFormats = {
    'jpg',
    'png',
    'webp',
    'bmp',
  };
  static const Set<String> supportedAnnotationModes = {
    'brush',
    'arrow',
    'rectangle',
    'circle',
    'text',
    'highlight',
    'mosaic',
  };

  final MethodChannel _channel;

  Future<LocalImageFile?> pickSingleImage() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'pickSingleImage',
      );
      if (result == null) {
        return null;
      }
      final file = LocalImageFile.fromMap(result);
      if (file.path.isEmpty) {
        throw const AppException('图片路径为空，请重新选择图片');
      }
      return file;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('选择图片失败，请重试', cause: error);
    }
  }

  Future<List<LocalImageFile>> pickMultipleImages() async {
    try {
      final result = await _channel.invokeListMethod<Object?>(
        'pickMultipleImages',
      );
      if (result == null || result.isEmpty) {
        return const [];
      }
      final files = <LocalImageFile>[];
      for (final item in result) {
        if (item is Map<Object?, Object?>) {
          final file = LocalImageFile.fromMap(item);
          if (file.path.isNotEmpty) {
            files.add(file);
          }
        }
      }
      return files;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } catch (error) {
      throw AppException('批量选择图片失败，请重试', cause: error);
    }
  }

  Future<PdfDocumentFile?> pickSinglePdf() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'pickSinglePdf',
      );
      if (result == null) {
        return null;
      }
      final file = PdfDocumentFile.fromMap(result);
      if (file.path.isEmpty) {
        throw const AppException('PDF 路径为空，请重新选择文件');
      }
      return file;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('选择 PDF 失败，请重试', cause: error);
    }
  }

  Future<BarcodeScanResult> scanBarcodeFromImage({
    required LocalImageFile source,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法识别二维码');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'scanBarcodeFromImage',
        <String, Object?>{'path': source.path},
      );
      if (result == null) {
        throw const AppException('识别结果为空，请重试');
      }
      final scan = BarcodeScanResult.fromMap(source: source, map: result);
      if (!scan.hasText) {
        throw const AppException('未识别到二维码或条形码内容');
      }
      return scan;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('识别二维码失败，请重试', cause: error);
    }
  }

  Future<CompressedImageFile> compressImage({
    required LocalImageFile source,
    required int quality,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法压缩');
    }
    if (quality < 1 || quality > 100) {
      throw const AppException('压缩质量必须在 1 到 100 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'compressImage',
        <String, Object?>{'path': source.path, 'quality': quality},
      );
      if (result == null) {
        throw const AppException('压缩结果为空，请重试');
      }
      final compressed = CompressedImageFile.fromMap(
        source: source,
        map: result,
      );
      if (compressed.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return compressed;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('压缩图片失败，请重试', cause: error);
    }
  }

  Future<RotatedImageFile> rotateImage({
    required LocalImageFile source,
    required int degrees,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法旋转');
    }
    if (degrees < -360 || degrees > 360) {
      throw const AppException('旋转角度必须在 -360 到 360 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'rotateImage',
        <String, Object?>{'path': source.path, 'degrees': degrees},
      );
      if (result == null) {
        throw const AppException('旋转结果为空，请重试');
      }
      final rotated = RotatedImageFile.fromMap(
        source: source,
        degrees: degrees,
        map: result,
      );
      if (rotated.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return rotated;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('旋转图片失败，请重试', cause: error);
    }
  }

  Future<FlippedImageFile> flipImage({
    required LocalImageFile source,
    required String direction,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法翻转');
    }
    final normalizedDirection = direction.trim().toLowerCase();
    final supportedDirections = {'horizontal', 'vertical'};
    if (!supportedDirections.contains(normalizedDirection)) {
      throw const AppException('翻转方向必须为水平或垂直');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'flipImage',
        <String, Object?>{
          'path': source.path,
          'direction': normalizedDirection,
        },
      );
      if (result == null) {
        throw const AppException('翻转结果为空，请重试');
      }
      final flipped = FlippedImageFile.fromMap(
        source: source,
        direction: normalizedDirection,
        map: result,
      );
      if (flipped.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return flipped;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('翻转图片失败，请重试', cause: error);
    }
  }

  Future<ResizedImageFile> resizeImage({
    required LocalImageFile source,
    required int width,
    required int height,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法调整尺寸');
    }
    if (width < 1 || height < 1) {
      throw const AppException('目标宽高必须大于 0');
    }
    if (width > maxResizeDimension || height > maxResizeDimension) {
      throw const AppException('目标宽高不能超过 10000 像素');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'resizeImage',
        <String, Object?>{
          'path': source.path,
          'width': width,
          'height': height,
        },
      );
      if (result == null) {
        throw const AppException('尺寸调整结果为空，请重试');
      }
      final resized = ResizedImageFile.fromMap(
        source: source,
        width: width,
        height: height,
        map: result,
      );
      if (resized.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return resized;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('调整图片尺寸失败，请重试', cause: error);
    }
  }

  Future<ConvertedImageFile> convertImage({
    required LocalImageFile source,
    required String format,
    required int quality,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法转换格式');
    }
    final normalizedFormat = format.trim().toLowerCase();
    if (!supportedConvertFormats.contains(normalizedFormat)) {
      throw const AppException('目标格式仅支持 JPG、PNG、WebP 或 BMP');
    }
    if (quality < 1 || quality > 100) {
      throw const AppException('导出质量必须在 1 到 100 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'convertImage',
        <String, Object?>{
          'path': source.path,
          'format': normalizedFormat,
          'quality': quality,
        },
      );
      if (result == null) {
        throw const AppException('格式转换结果为空，请重试');
      }
      final converted = ConvertedImageFile.fromMap(
        source: source,
        format: normalizedFormat,
        map: result,
      );
      if (converted.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return converted;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('转换图片格式失败，请重试', cause: error);
    }
  }

  Future<CroppedImageFile> cropImage({
    required LocalImageFile source,
    required double aspectRatio,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法裁剪');
    }
    if (!aspectRatio.isFinite || aspectRatio <= 0) {
      throw const AppException('裁剪比例必须大于 0');
    }
    if (aspectRatio < 0.1 || aspectRatio > 10) {
      throw const AppException('裁剪比例必须在 0.1 到 10 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'cropImage',
        <String, Object?>{'path': source.path, 'aspectRatio': aspectRatio},
      );
      if (result == null) {
        throw const AppException('裁剪结果为空，请重试');
      }
      final cropped = CroppedImageFile.fromMap(
        source: source,
        aspectRatio: aspectRatio,
        map: result,
      );
      if (cropped.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return cropped;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('裁剪图片失败，请重试', cause: error);
    }
  }

  Future<MergedImageFile> mergeImages({
    required List<LocalImageFile> sources,
    required String mode,
    required int columns,
    required int spacing,
  }) async {
    if (sources.length < 2) {
      throw const AppException('请至少选择两张图片进行拼接');
    }
    if (sources.length > maxMergeImages) {
      throw const AppException('单次最多拼接 20 张图片');
    }
    final normalizedMode = mode.trim().toLowerCase();
    if (!{'horizontal', 'vertical', 'grid'}.contains(normalizedMode)) {
      throw const AppException('拼接模式无效');
    }
    if (columns < 1 || columns > 10) {
      throw const AppException('网格列数必须在 1 到 10 之间');
    }
    if (spacing < 0 || spacing > 100) {
      throw const AppException('图片间距必须在 0 到 100 像素之间');
    }
    final paths = sources.map((image) => image.path.trim()).toList();
    if (paths.any((path) => path.isEmpty)) {
      throw const AppException('图片路径为空，无法拼接');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'mergeImages',
        <String, Object?>{
          'paths': paths,
          'mode': normalizedMode,
          'columns': columns,
          'spacing': spacing,
        },
      );
      if (result == null) {
        throw const AppException('拼接结果为空，请重试');
      }
      final merged = MergedImageFile.fromMap(
        sources: sources,
        mode: normalizedMode,
        map: result,
      );
      if (merged.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return merged;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('拼接图片失败，请重试', cause: error);
    }
  }

  Future<WatermarkedImageFile> addTextWatermark({
    required LocalImageFile source,
    required String text,
    required String position,
    required int fontSize,
    required int opacity,
    required String color,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法添加水印');
    }
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const AppException('水印文字不能为空');
    }
    if (normalizedText.length > 80) {
      throw const AppException('水印文字不能超过 80 个字符');
    }
    final normalizedPosition = position.trim().toLowerCase();
    const supportedPositions = {
      'topleft',
      'topright',
      'bottomleft',
      'bottomright',
      'center',
      'tile',
    };
    if (!supportedPositions.contains(normalizedPosition)) {
      throw const AppException('水印位置无效');
    }
    if (fontSize < 12 || fontSize > 160) {
      throw const AppException('字号必须在 12 到 160 之间');
    }
    if (opacity < 10 || opacity > 100) {
      throw const AppException('透明度必须在 10 到 100 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'addTextWatermark',
        <String, Object?>{
          'path': source.path,
          'text': normalizedText,
          'position': normalizedPosition,
          'fontSize': fontSize,
          'opacity': opacity,
          'color': color,
        },
      );
      if (result == null) {
        throw const AppException('水印结果为空，请重试');
      }
      final watermarked = WatermarkedImageFile.fromMap(
        source: source,
        text: normalizedText,
        position: normalizedPosition,
        map: result,
      );
      if (watermarked.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return watermarked;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('添加文字水印失败，请重试', cause: error);
    }
  }

  Future<ImageWatermarkedFile> addImageWatermark({
    required LocalImageFile source,
    required LocalImageFile watermark,
    required String position,
    required int opacity,
    required int scalePercent,
    required int rotationDegrees,
  }) async {
    if (source.path.trim().isEmpty || watermark.path.trim().isEmpty) {
      throw const AppException('底图或水印图片路径为空');
    }
    final normalizedPosition = position.trim().toLowerCase();
    const supportedPositions = {
      'topleft',
      'topright',
      'bottomleft',
      'bottomright',
      'center',
      'tile',
    };
    if (!supportedPositions.contains(normalizedPosition)) {
      throw const AppException('水印位置无效');
    }
    if (opacity < 10 || opacity > 100) {
      throw const AppException('透明度必须在 10 到 100 之间');
    }
    if (scalePercent < 5 || scalePercent > 100) {
      throw const AppException('水印缩放必须在 5% 到 100% 之间');
    }
    if (rotationDegrees < -180 || rotationDegrees > 180) {
      throw const AppException('旋转角度必须在 -180 到 180 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'addImageWatermark',
        <String, Object?>{
          'path': source.path,
          'watermarkPath': watermark.path,
          'position': normalizedPosition,
          'opacity': opacity,
          'scalePercent': scalePercent,
          'rotationDegrees': rotationDegrees,
        },
      );
      if (result == null) {
        throw const AppException('图片水印结果为空，请重试');
      }
      final watermarked = ImageWatermarkedFile.fromMap(
        source: source,
        watermark: watermark,
        position: normalizedPosition,
        opacity: opacity,
        scalePercent: scalePercent,
        rotationDegrees: rotationDegrees,
        map: result,
      );
      if (watermarked.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return watermarked;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('添加图片水印失败，请重试', cause: error);
    }
  }

  Future<FilteredImageFile> applyFilter({
    required LocalImageFile source,
    required String filter,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法应用滤镜');
    }
    final normalizedFilter = filter.trim().toLowerCase();
    if (!supportedFilters.contains(normalizedFilter)) {
      throw const AppException('滤镜类型不支持');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'applyFilter',
        <String, Object?>{'path': source.path, 'filter': normalizedFilter},
      );
      if (result == null) {
        throw const AppException('滤镜结果为空，请重试');
      }
      final filtered = FilteredImageFile.fromMap(
        source: source,
        filter: normalizedFilter,
        map: result,
      );
      if (filtered.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return filtered;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('应用图片滤镜失败，请重试', cause: error);
    }
  }

  Future<GridImageFile> splitGridImage({
    required LocalImageFile source,
    required int gridSize,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法切图');
    }
    if (gridSize < minGridSize || gridSize > maxGridSize) {
      throw const AppException('网格大小必须在 2 到 5 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'splitGridImage',
        <String, Object?>{'path': source.path, 'gridSize': gridSize},
      );
      if (result == null) {
        throw const AppException('切图结果为空，请重试');
      }
      final gridImage = GridImageFile.fromMap(
        source: source,
        gridSize: gridSize,
        map: result,
      );
      if (gridImage.outputDirectory.isEmpty || gridImage.outputPaths.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      if (gridImage.pieceCount != gridSize * gridSize) {
        throw const AppException('切片数量异常，请重试');
      }
      return gridImage;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('九宫格切图失败，请重试', cause: error);
    }
  }

  Future<ExifInfo> readExif({required LocalImageFile source}) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法读取 EXIF');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'readExif',
        <String, Object?>{'path': source.path},
      );
      if (result == null) {
        throw const AppException('EXIF 结果为空，请重试');
      }
      return ExifInfo.fromMap(source: source, map: result);
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('读取 EXIF 失败，请重试', cause: error);
    }
  }

  Future<ExifCleanedImageFile> removeExif({
    required LocalImageFile source,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法删除 EXIF');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'removeExif',
        <String, Object?>{'path': source.path},
      );
      if (result == null) {
        throw const AppException('EXIF 清理结果为空，请重试');
      }
      final cleaned = ExifCleanedImageFile.fromMap(source: source, map: result);
      if (cleaned.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return cleaned;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('删除 EXIF 失败，请重试', cause: error);
    }
  }

  Future<PdfImageFile> imagesToPdf({
    required List<LocalImageFile> sources,
    required String pageSize,
    required String orientation,
  }) async {
    if (sources.isEmpty) {
      throw const AppException('请至少选择一张图片生成 PDF');
    }
    if (sources.length > maxPdfImages) {
      throw const AppException('单次最多转换 50 张图片');
    }
    final normalizedPageSize = pageSize.trim().toLowerCase();
    if (!{'a4', 'a3'}.contains(normalizedPageSize)) {
      throw const AppException('PDF 页面规格仅支持 A4 或 A3');
    }
    final normalizedOrientation = orientation.trim().toLowerCase();
    if (!{'portrait', 'landscape'}.contains(normalizedOrientation)) {
      throw const AppException('PDF 页面方向无效');
    }
    final paths = sources.map((image) => image.path.trim()).toList();
    if (paths.any((path) => path.isEmpty)) {
      throw const AppException('图片路径为空，无法生成 PDF');
    }

    try {
      final result = await _channel
          .invokeMapMethod<Object?, Object?>('imagesToPdf', <String, Object?>{
            'paths': paths,
            'pageSize': normalizedPageSize,
            'orientation': normalizedOrientation,
          });
      if (result == null) {
        throw const AppException('PDF 生成结果为空，请重试');
      }
      final pdf = PdfImageFile.fromMap(
        sources: sources,
        pageSize: normalizedPageSize,
        orientation: normalizedOrientation,
        map: result,
      );
      if (pdf.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      if (pdf.pageCount != sources.length) {
        throw const AppException('PDF 页数异常，请重试');
      }
      return pdf;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('生成 PDF 失败，请重试', cause: error);
    }
  }

  Future<GifImageFile> imagesToGif({
    required List<LocalImageFile> sources,
    required int delayMs,
  }) async {
    if (sources.length < 2) {
      throw const AppException('请至少选择两张图片生成 GIF');
    }
    if (sources.length > maxGifImages) {
      throw const AppException('单次最多转换 30 张图片');
    }
    if (delayMs < minGifDelayMs || delayMs > maxGifDelayMs) {
      throw const AppException('每帧间隔必须在 50 到 2000 毫秒之间');
    }
    final paths = sources.map((image) => image.path.trim()).toList();
    if (paths.any((path) => path.isEmpty)) {
      throw const AppException('图片路径为空，无法生成 GIF');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'imagesToGif',
        <String, Object?>{'paths': paths, 'delayMs': delayMs},
      );
      if (result == null) {
        throw const AppException('GIF 生成结果为空，请重试');
      }
      final gif = GifImageFile.fromMap(
        sources: sources,
        delayMs: delayMs,
        map: result,
      );
      if (gif.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      if (gif.frameCount != sources.length) {
        throw const AppException('GIF 帧数异常，请重试');
      }
      if (!gif.hasValidDimensions) {
        throw const AppException('GIF 输出尺寸异常，请重试');
      }
      return gif;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('生成 GIF 失败，请重试', cause: error);
    }
  }

  Future<GifFramesExport> exportGifFrames({
    required LocalImageFile source,
    required int frameStepMs,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('GIF 路径为空，无法拆帧');
    }
    if (frameStepMs < minGifFrameStepMs || frameStepMs > maxGifFrameStepMs) {
      throw const AppException('拆帧间隔必须在 50 到 1000 毫秒之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'exportGifFrames',
        <String, Object?>{'path': source.path, 'frameStepMs': frameStepMs},
      );
      if (result == null) {
        throw const AppException('GIF 拆帧结果为空，请重试');
      }
      final export = GifFramesExport.fromMap(
        source: source,
        frameStepMs: frameStepMs,
        map: result,
      );
      if (!export.isComplete) {
        throw const AppException('GIF 拆帧数量异常，请重试');
      }
      return export;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('GIF 拆帧失败，请重试', cause: error);
    }
  }

  Future<CompressedGifFile> compressGif({
    required LocalImageFile source,
    required int frameStepMs,
    required int scalePercent,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('GIF 路径为空，无法压缩');
    }
    if (frameStepMs < minGifFrameStepMs || frameStepMs > maxGifFrameStepMs) {
      throw const AppException('采样间隔必须在 50 到 1000 毫秒之间');
    }
    if (scalePercent < minGifScalePercent ||
        scalePercent > maxGifScalePercent) {
      throw const AppException('缩放比例必须在 25% 到 100% 之间');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'compressGif',
        <String, Object?>{
          'path': source.path,
          'frameStepMs': frameStepMs,
          'scalePercent': scalePercent,
        },
      );
      if (result == null) {
        throw const AppException('GIF 压缩结果为空，请重试');
      }
      final compressed = CompressedGifFile.fromMap(
        source: source,
        frameStepMs: frameStepMs,
        scalePercent: scalePercent,
        map: result,
      );
      if (!compressed.hasValidOutput) {
        throw const AppException('GIF 压缩输出异常，请重试');
      }
      return compressed;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('GIF 压缩失败，请重试', cause: error);
    }
  }

  Future<PdfPageImageFile> exportPdfPageAsImage({
    required PdfDocumentFile source,
    required int pageNumber,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('PDF 路径为空，无法导出图片');
    }
    if (pageNumber < 1) {
      throw const AppException('PDF 页码必须大于 0');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'exportPdfPageAsImage',
        <String, Object?>{'path': source.path, 'pageNumber': pageNumber},
      );
      if (result == null) {
        throw const AppException('PDF 页面导出结果为空，请重试');
      }
      final image = PdfPageImageFile.fromMap(
        sourcePath: source.path,
        sourceName: source.name,
        requestedPageNumber: pageNumber,
        map: result,
      );
      if (image.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      if (!image.hasValidDimensions) {
        throw const AppException('导出图片尺寸异常，请重试');
      }
      return image;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('PDF 页面导出图片失败，请重试', cause: error);
    }
  }

  Future<PdfPagesImageExport> exportPdfAllPagesAsImages({
    required PdfDocumentFile source,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('PDF 路径为空，无法导出图片');
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'exportPdfAllPagesAsImages',
        <String, Object?>{'path': source.path},
      );
      if (result == null) {
        throw const AppException('PDF 全页导出结果为空，请重试');
      }
      final export = PdfPagesImageExport.fromMap(
        sourcePath: source.path,
        sourceName: source.name,
        map: result,
      );
      if (export.outputDirectory.isEmpty || export.outputPaths.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      if (!export.isComplete) {
        throw const AppException('PDF 页面导出数量异常，请重试');
      }
      return export;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('PDF 全页导出图片失败，请重试', cause: error);
    }
  }

  Future<AnnotatedImageFile> annotateImage({
    required LocalImageFile source,
    required String mode,
    required String text,
    required String color,
    required int strokeWidth,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法标注');
    }
    final normalizedMode = mode.trim().toLowerCase();
    if (!supportedAnnotationModes.contains(normalizedMode)) {
      throw const AppException('标注模式不支持');
    }
    final normalizedText = text.trim();
    if (normalizedMode == 'text' && normalizedText.isEmpty) {
      throw const AppException('文本标注内容不能为空');
    }
    if (normalizedText.length > 40) {
      throw const AppException('文本标注不能超过 40 个字符');
    }
    if (strokeWidth < 2 || strokeWidth > 48) {
      throw const AppException('标注粗细必须在 2 到 48 之间');
    }

    try {
      final result = await _channel
          .invokeMapMethod<Object?, Object?>('annotateImage', <String, Object?>{
            'path': source.path,
            'mode': normalizedMode,
            'text': normalizedText,
            'color': color,
            'strokeWidth': strokeWidth,
          });
      if (result == null) {
        throw const AppException('标注结果为空，请重试');
      }
      final annotated = AnnotatedImageFile.fromMap(
        source: source,
        mode: normalizedMode,
        map: result,
      );
      if (annotated.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      return annotated;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('图片标注失败，请重试', cause: error);
    }
  }

  String _messageForCode(String code) {
    return switch (code) {
      'file_not_found' => '图片文件不存在，请重新选择',
      'invalid_image' => '图片格式不支持或文件已损坏',
      'invalid_pdf' => 'PDF 文件无效或已损坏',
      'not_found' => '未识别到二维码或条形码内容',
      'invalid_args' => '图片处理参数无效，请检查后重试',
      'export_failed' => '导出图片失败，请检查存储空间',
      'activity_missing' => '当前设备没有可用的图片选择器',
      'busy' => '已有图片任务正在进行，请稍后再试',
      _ => '图片处理失败，请重试',
    };
  }
}
