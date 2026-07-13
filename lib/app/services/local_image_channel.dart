import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../exceptions/app_exception.dart';
import '../models/annotated_image_file.dart';
import '../models/barcode_scan_result.dart';
import '../models/compressed_gif_file.dart';
import '../models/compressed_image_file.dart';
import '../models/converted_image_file.dart';
import '../models/cropped_image_file.dart';
import '../models/exif_cleaned_image_file.dart';
import '../models/exif_info.dart';
import '../models/filtered_image_file.dart';
import '../models/flipped_image_file.dart';
import '../models/gif_frames_export.dart';
import '../models/gif_image_file.dart';
import '../models/grid_image_file.dart';
import '../models/image_watermarked_file.dart';
import '../models/local_image_file.dart';
import '../models/merged_image_file.dart';
import '../models/pdf_document_file.dart';
import '../models/pdf_image_file.dart';
import '../models/pdf_page_image_file.dart';
import '../models/pdf_pages_image_export.dart';
import '../models/resized_image_file.dart';
import '../models/rotated_image_file.dart';
import '../models/watermarked_image_file.dart';
import '../utils/platform_path.dart';
import '../utils/watermark_opacity.dart';
import 'gif_processing_service.dart';
import 'watermark_processing_service.dart';

/// 相册保存回调，用于测试时绕过真实系统相册权限。
typedef GallerySaveCallback =
    Future<void> Function(String imagePath, {String? album});

/// 临时目录提供器，用于测试时把导出文件写入可控目录。
typedef TemporaryDirectoryProvider = Future<Directory> Function();

/// 本地图片能力服务，封装选图、相册保存和图片处理。
///
/// 设计意图：常用图片能力使用 Flutter 插件和 Dart 侧图像处理，减少平台通道
/// 依赖；GIF 使用后台 isolate 处理，PDF、EXIF 和扫码等能力保留原生通道。
class LocalImageChannel {
  LocalImageChannel({
    MethodChannel? channel,
    ImagePicker? imagePicker,
    GallerySaveCallback? gallerySaver,
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _imagePicker = imagePicker ?? ImagePicker(),
       _gallerySaver = gallerySaver,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

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
  static const String _defaultAlbum = 'ImageToolKit';
  static const int _maxDecodedPixels = 120000000;
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
  final ImagePicker _imagePicker;
  final GallerySaveCallback? _gallerySaver;
  final TemporaryDirectoryProvider _temporaryDirectoryProvider;

  Future<LocalImageFile?> pickSingleImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) {
        return null;
      }
      final file = await _localImageFromXFile(pickedFile);
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
      final pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isEmpty) {
        return const [];
      }
      final files = <LocalImageFile>[];
      for (final pickedFile in pickedFiles) {
        final file = await _localImageFromXFile(pickedFile);
        if (file.path.isNotEmpty) {
          files.add(file);
        }
      }
      return files;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } catch (error) {
      throw AppException('批量选择图片失败，请重试', cause: error);
    }
  }

  Future<void> saveImageToGallery(String imagePath, {String? album}) async {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty) {
      throw const AppException('导出路径为空，无法保存到相册');
    }
    final file = File(normalizedPath);
    if (!file.existsSync()) {
      throw const AppException('导出文件不存在，无法保存到相册');
    }

    try {
      final targetAlbum = album?.trim().isNotEmpty == true
          ? album!.trim()
          : _defaultAlbum;
      if (_gallerySaver != null) {
        await _gallerySaver(normalizedPath, album: targetAlbum);
        return;
      }
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      final granted = hasAccess || await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw const AppException('相册访问权限被拒绝，无法保存图片');
      }
      await Gal.putImage(normalizedPath, album: targetAlbum);
    } on GalException catch (error) {
      throw AppException(_messageForGalException(error), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('保存图片到相册失败，请重试', cause: error);
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
      final decoded = await _readImage(source.path);
      final output = await _createOutputFile(
        prefix: 'compressed',
        extension: 'jpg',
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        output.path,
        minWidth: decoded.width,
        minHeight: decoded.height,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result == null) {
        throw const AppException('压缩结果为空，请重试');
      }
      final outputFile = File(result.path);
      if (!outputFile.existsSync()) {
        throw const AppException('导出路径为空，请重试');
      }
      await saveImageToGallery(outputFile.path);
      final compressed = CompressedImageFile(
        source: source,
        outputPath: outputFile.path,
        outputSizeBytes: await outputFile.length(),
      );
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
      final decoded = await _readImage(source.path);
      final normalizedDegrees = degrees % 360;
      final rotatedImage = normalizedDegrees == 0
          ? img.Image.from(decoded)
          : img.copyRotate(
              decoded,
              angle: normalizedDegrees,
              interpolation: img.Interpolation.linear,
            );
      final output = await _writeEncodedImage(
        image: rotatedImage,
        prefix: 'rotated',
        extension: 'png',
      );
      await saveImageToGallery(output.path);
      final rotated = RotatedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        degrees: degrees,
      );
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
      final decoded = await _readImage(source.path);
      final flippedImage = normalizedDirection == 'horizontal'
          ? img.flipHorizontal(decoded)
          : img.flipVertical(decoded);
      final output = await _writeEncodedImage(
        image: flippedImage,
        prefix: 'flipped',
        extension: 'png',
      );
      await saveImageToGallery(output.path);
      final flipped = FlippedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        direction: normalizedDirection,
      );
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
      final decoded = await _readImage(source.path);
      final resizedImage = img.copyResize(
        decoded,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );
      final output = await _writeEncodedImage(
        image: resizedImage,
        prefix: 'resized',
        extension: 'png',
      );
      await saveImageToGallery(output.path);
      final resized = ResizedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        width: width,
        height: height,
      );
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
      final output = await _convertImageFile(
        source: source,
        format: normalizedFormat,
        quality: quality,
      );
      await saveImageToGallery(output.path);
      final converted = ConvertedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        format: normalizedFormat,
        mimeType: _mimeTypeForFormat(normalizedFormat),
      );
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
    double? cropLeftRatio,
    double? cropTopRatio,
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
    final hasCropPosition = cropLeftRatio != null || cropTopRatio != null;
    if (hasCropPosition) {
      if (cropLeftRatio == null ||
          cropTopRatio == null ||
          !cropLeftRatio.isFinite ||
          !cropTopRatio.isFinite ||
          cropLeftRatio < 0 ||
          cropTopRatio < 0 ||
          cropLeftRatio > 1 ||
          cropTopRatio > 1) {
        throw const AppException('裁剪区域无效，请调整裁剪框后重试');
      }
    }

    try {
      final decoded = await _readImage(source.path);
      final cropRect = _cropRect(
        decoded,
        aspectRatio: aspectRatio,
        cropLeftRatio: cropLeftRatio,
        cropTopRatio: cropTopRatio,
      );
      final croppedImage = img.copyCrop(
        decoded,
        x: cropRect.left,
        y: cropRect.top,
        width: cropRect.width,
        height: cropRect.height,
      );
      final output = await _writeEncodedImage(
        image: croppedImage,
        prefix: 'cropped',
        extension: 'png',
      );
      await saveImageToGallery(output.path);
      final cropped = CroppedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        width: croppedImage.width,
        height: croppedImage.height,
        aspectRatio: aspectRatio,
      );
      return cropped;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('裁剪图片失败，请重试', cause: error);
    }
  }

  Future<CroppedImageFile> saveCroppedImageBytes({
    required LocalImageFile source,
    required Uint8List bytes,
    required double aspectRatio,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法裁剪');
    }
    if (bytes.isEmpty) {
      throw const AppException('裁剪结果为空，请重试');
    }
    if (!aspectRatio.isFinite || aspectRatio <= 0) {
      throw const AppException('裁剪比例必须大于 0');
    }
    if (aspectRatio < 0.1 || aspectRatio > 10) {
      throw const AppException('裁剪比例必须在 0.1 到 10 之间');
    }

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        throw const AppException('裁剪结果格式异常，请重试');
      }
      final output = await _createOutputFile(
        prefix: 'cropped',
        extension: 'png',
      );
      await output.writeAsBytes(bytes, flush: true);
      await saveImageToGallery(output.path);
      return CroppedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        width: decoded.width,
        height: decoded.height,
        aspectRatio: aspectRatio,
      );
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
    required int spacing,
    required String backgroundColor,
    required int borderWidth,
    required int cornerRadius,
    required String scaleMode,
  }) async {
    if (sources.length < 2) {
      throw const AppException('请至少选择两张图片进行拼接');
    }
    if (sources.length > maxMergeImages) {
      throw const AppException('单次最多拼接 20 张图片');
    }
    final normalizedMode = mode.trim().toLowerCase();
    if (!{'horizontal', 'vertical'}.contains(normalizedMode)) {
      throw const AppException('拼接模式无效');
    }
    final normalizedScaleMode = scaleMode.trim().toLowerCase();
    if (!{'same_width', 'same_height'}.contains(normalizedScaleMode)) {
      throw const AppException('缩放模式无效');
    }
    if (spacing < 0 || spacing > 100) {
      throw const AppException('图片间距必须在 0 到 100 像素之间');
    }
    if (borderWidth < 0 || borderWidth > 50) {
      throw const AppException('边框宽度必须在 0 到 50 像素之间');
    }
    if (cornerRadius < 0 || cornerRadius > 200) {
      throw const AppException('圆角半径必须在 0 到 200 像素之间');
    }
    final normalizedBackgroundColor = _normalizeHexColor(backgroundColor);
    if (normalizedBackgroundColor == null) {
      throw const AppException('背景颜色必须是 #RRGGBB 格式');
    }
    final paths = sources.map((image) => image.path.trim()).toList();
    if (paths.any((path) => path.isEmpty)) {
      throw const AppException('图片路径为空，无法拼接');
    }

    try {
      final result = await _channel
          .invokeMapMethod<Object?, Object?>('mergeImages', <String, Object?>{
            'paths': paths,
            'mode': normalizedMode,
            'spacing': spacing,
            'backgroundColor': normalizedBackgroundColor,
            'borderWidth': borderWidth,
            'cornerRadius': cornerRadius,
            'scaleMode': normalizedScaleMode,
          });
      if (result == null) {
        throw const AppException('拼接结果为空，请重试');
      }
      final merged = MergedImageFile.fromMap(
        sources: sources,
        mode: normalizedMode,
        backgroundColor: normalizedBackgroundColor,
        borderWidth: borderWidth,
        cornerRadius: cornerRadius,
        scaleMode: normalizedScaleMode,
        map: result,
      );
      if (merged.outputPath.isEmpty) {
        throw const AppException('导出路径为空，请重试');
      }
      await saveImageToGallery(merged.outputPath);
      return merged;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('拼接图片失败，请重试', cause: error);
    }
  }

  String? _normalizeHexColor(String value) {
    final normalized = value.trim().toUpperCase();
    final pattern = RegExp(r'^#[0-9A-F]{6}$');
    if (!pattern.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  Future<WatermarkedImageFile> addTextWatermark({
    required LocalImageFile source,
    required String text,
    required String position,
    required int fontSize,
    required int opacity,
    required int spacing,
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
    if (spacing < 8 || spacing > 160) {
      throw const AppException('水印间距必须在 8 到 160 之间');
    }

    try {
      final output = await _createOutputFile(
        prefix: 'text_watermark',
        extension: 'png',
      );
      final textLayer = await _createTextWatermarkLayer(
        text: normalizedText,
        fontSize: fontSize,
        opacity: opacity,
        color: color,
        maxWidth: source.hasValidDimensions ? source.width : maxResizeDimension,
      );
      final processed = await WatermarkProcessingService.addTextWatermark(
        sourcePath: source.path,
        textLayerPng: Uint8List.fromList(img.encodePng(textLayer)),
        outputPath: output.path,
        position: normalizedPosition,
        spacing: spacing,
      );
      await saveImageToGallery(output.path);
      final watermarked = WatermarkedImageFile(
        source: source,
        outputPath: processed['outputPath'] as String? ?? output.path,
        outputSizeBytes:
            processed['outputSizeBytes'] as int? ?? await output.length(),
        text: normalizedText,
        position: normalizedPosition,
      );
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
    required int spacing,
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
    if (spacing < 8 || spacing > 160) {
      throw const AppException('水印间距必须在 8 到 160 之间');
    }
    if (rotationDegrees < -180 || rotationDegrees > 180) {
      throw const AppException('旋转角度必须在 -180 到 180 之间');
    }

    try {
      final output = await _createOutputFile(
        prefix: 'image_watermark',
        extension: 'png',
      );
      final processed = await WatermarkProcessingService.addImageWatermark(
        sourcePath: source.path,
        watermarkPath: watermark.path,
        outputPath: output.path,
        position: normalizedPosition,
        opacity: opacity,
        scalePercent: scalePercent,
        spacing: spacing,
        rotationDegrees: rotationDegrees,
      );
      await saveImageToGallery(output.path);
      final watermarked = ImageWatermarkedFile(
        source: source,
        watermark: watermark,
        outputPath: processed['outputPath'] as String? ?? output.path,
        outputSizeBytes:
            processed['outputSizeBytes'] as int? ?? await output.length(),
        position: normalizedPosition,
        opacity: opacity,
        scalePercent: scalePercent,
        rotationDegrees: rotationDegrees,
      );
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
      final filteredImage = await _readImage(source.path);
      _applyFilterToImage(filteredImage, normalizedFilter);
      final output = await _writeEncodedImage(
        image: filteredImage,
        prefix: 'filtered',
        extension: 'png',
      );
      await saveImageToGallery(output.path);
      final filtered = FilteredImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        filter: normalizedFilter,
      );
      return filtered;
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('应用图片滤镜失败，请重试', cause: error);
    }
  }

  Future<AnnotatedImageFile> saveEditedImageBytes({
    required LocalImageFile source,
    required Uint8List bytes,
    String? filter,
    int rotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
    int? resizeWidth,
    int? resizeHeight,
    double? cropAspectRatio,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法导出编辑图片');
    }
    if (bytes.isEmpty) {
      throw const AppException('编辑结果为空，请重试');
    }

    try {
      final editedImage = processEditedImageBytes(
        bytes: bytes,
        filter: filter,
        rotationDegrees: rotationDegrees,
        flipHorizontal: flipHorizontal,
        flipVertical: flipVertical,
        resizeWidth: resizeWidth,
        resizeHeight: resizeHeight,
        cropAspectRatio: cropAspectRatio,
      );
      final output = await _writeEncodedImage(
        image: editedImage,
        prefix: 'edited',
        extension: 'png',
      );
      await saveImageToGallery(output.path);
      return AnnotatedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        mode: 'editor',
      );
    } on PlatformException catch (error) {
      throw AppException(_messageForCode(error.code), cause: error);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('图片编辑导出失败，请重试', cause: error);
    }
  }

  img.Image processEditedImageBytes({
    required Uint8List bytes,
    String? filter,
    int rotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
    int? resizeWidth,
    int? resizeHeight,
    double? cropAspectRatio,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw const AppException('编辑结果格式异常，请重试');
    }
    return processEditedImage(
      image: decoded,
      filter: filter,
      rotationDegrees: rotationDegrees,
      flipHorizontal: flipHorizontal,
      flipVertical: flipVertical,
      resizeWidth: resizeWidth,
      resizeHeight: resizeHeight,
      cropAspectRatio: cropAspectRatio,
    );
  }

  img.Image processEditedImage({
    required img.Image image,
    String? filter,
    int rotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
    int? resizeWidth,
    int? resizeHeight,
    double? cropAspectRatio,
  }) {
    if (image.width <= 0 || image.height <= 0) {
      throw const AppException('编辑结果格式异常，请重试');
    }
    if (image.width * image.height > _maxDecodedPixels) {
      throw const AppException('图片尺寸过大，请先缩小后再处理');
    }
    final normalizedFilter = filter?.trim().toLowerCase();
    if (normalizedFilter != null &&
        normalizedFilter.isNotEmpty &&
        !supportedFilters.contains(normalizedFilter)) {
      throw const AppException('滤镜类型不支持');
    }
    final targetWidth = resizeWidth;
    final targetHeight = resizeHeight;
    final needsResize = targetWidth != null || targetHeight != null;
    if (needsResize) {
      if (targetWidth == null || targetHeight == null) {
        throw const AppException('目标宽高必须同时填写');
      }
      if (targetWidth < 1 || targetHeight < 1) {
        throw const AppException('目标宽高必须大于 0');
      }
      if (targetWidth > maxResizeDimension ||
          targetHeight > maxResizeDimension) {
        throw const AppException('目标宽高不能超过 10000 像素');
      }
    }
    if (cropAspectRatio != null) {
      if (!cropAspectRatio.isFinite || cropAspectRatio <= 0) {
        throw const AppException('裁剪比例必须大于 0');
      }
      if (cropAspectRatio < 0.1 || cropAspectRatio > 10) {
        throw const AppException('裁剪比例必须在 0.1 到 10 之间');
      }
    }

    var output = img.Image.from(image);
    if (cropAspectRatio != null) {
      final cropRect = _cropRect(output, aspectRatio: cropAspectRatio);
      output = img.copyCrop(
        output,
        x: cropRect.left,
        y: cropRect.top,
        width: cropRect.width,
        height: cropRect.height,
      );
    }

    final normalizedDegrees = rotationDegrees % 360;
    if (normalizedDegrees != 0) {
      output = img.copyRotate(
        output,
        angle: normalizedDegrees,
        interpolation: img.Interpolation.linear,
      );
    }
    if (flipHorizontal) {
      output = img.flipHorizontal(output);
    }
    if (flipVertical) {
      output = img.flipVertical(output);
    }
    if (normalizedFilter != null && normalizedFilter.isNotEmpty) {
      _applyFilterToImage(output, normalizedFilter);
    }
    if (needsResize) {
      output = img.copyResize(
        output,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }
    return output;
  }

  Future<GridImageFile> splitGridImage({
    required LocalImageFile source,
    required int gridSize,
    double? cropLeftRatio,
    double? cropTopRatio,
    double? cropSizeRatio,
  }) async {
    if (source.path.trim().isEmpty) {
      throw const AppException('图片路径为空，无法切图');
    }
    if (gridSize < minGridSize || gridSize > maxGridSize) {
      throw const AppException('网格大小必须在 2 到 5 之间');
    }
    final hasCropSelection =
        cropLeftRatio != null || cropTopRatio != null || cropSizeRatio != null;
    if (hasCropSelection) {
      if (cropLeftRatio == null ||
          cropTopRatio == null ||
          cropSizeRatio == null ||
          !isValidGridCropRatio(
            left: cropLeftRatio,
            top: cropTopRatio,
            size: cropSizeRatio,
          )) {
        throw const AppException('切图区域无效，请调整网格位置后重试');
      }
    }

    try {
      final decoded = await _readImage(source.path);
      final cropRect = _gridCropRect(
        decoded,
        cropLeftRatio: cropLeftRatio,
        cropTopRatio: cropTopRatio,
        cropSizeRatio: cropSizeRatio,
      );
      final pieceSize = cropRect.width ~/ gridSize;
      if (pieceSize <= 0) {
        throw const AppException('切图区域过小，请调整网格位置后重试');
      }
      final outputDirectory = await _createOutputDirectory('grid');
      final outputPaths = <String>[];
      var outputSizeBytes = 0;
      for (var row = 0; row < gridSize; row++) {
        for (var column = 0; column < gridSize; column++) {
          final piece = img.copyCrop(
            decoded,
            x: cropRect.left + column * pieceSize,
            y: cropRect.top + row * pieceSize,
            width: pieceSize,
            height: pieceSize,
          );
          final output = File(
            '${outputDirectory.path}\\grid_${row + 1}_${column + 1}.png',
          );
          await output.writeAsBytes(img.encodePng(piece), flush: true);
          await saveImageToGallery(output.path);
          outputPaths.add(output.path);
          outputSizeBytes += await output.length();
        }
      }
      final gridImage = GridImageFile(
        source: source,
        outputDirectory: outputDirectory.path,
        outputPaths: List<String>.unmodifiable(outputPaths),
        outputSizeBytes: outputSizeBytes,
        gridSize: gridSize,
        pieceCount: outputPaths.length,
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

  /// 校验网格选择器传入的归一化字段。
  ///
  /// left/top 分别基于画布宽高，size 基于最短边，三者不能直接相加比较；
  /// 最终像素区域由 [_gridCropRect] 统一收敛到图片边界。
  static bool isValidGridCropRatio({
    required double left,
    required double top,
    required double size,
  }) {
    return left.isFinite &&
        top.isFinite &&
        size.isFinite &&
        left >= 0 &&
        top >= 0 &&
        size > 0 &&
        size <= 1 &&
        left <= 1 &&
        top <= 1;
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
      await saveImageToGallery(cleaned.outputPath);
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
      final output = await _createOutputFile(prefix: 'gif', extension: 'gif');
      final result = await GifProcessingService.createGif(
        paths: paths,
        outputPath: output.path,
        delayMs: delayMs,
      );
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
      await saveImageToGallery(gif.outputPath);
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
      final outputDirectory = await _createOutputDirectory(
        'gif_frames_${DateTime.now().millisecondsSinceEpoch}',
      );
      final result = await GifProcessingService.exportFrames(
        sourcePath: source.path,
        outputDirectory: outputDirectory.path,
        frameStepMs: frameStepMs,
      );
      final export = GifFramesExport.fromMap(
        source: source,
        frameStepMs: frameStepMs,
        map: result,
      );
      if (!export.isComplete) {
        throw const AppException('GIF 拆帧数量异常，请重试');
      }
      for (final outputPath in export.outputPaths) {
        await saveImageToGallery(outputPath);
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
      final output = await _createOutputFile(
        prefix: 'compressed_gif',
        extension: 'gif',
      );
      final result = await GifProcessingService.compressGif(
        sourcePath: source.path,
        outputPath: output.path,
        frameStepMs: frameStepMs,
        scalePercent: scalePercent,
      );
      final compressed = CompressedGifFile.fromMap(
        source: source,
        frameStepMs: frameStepMs,
        scalePercent: scalePercent,
        map: result,
      );
      if (!compressed.hasValidOutput) {
        throw const AppException('GIF 压缩输出异常，请重试');
      }
      await saveImageToGallery(compressed.outputPath);
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
      await saveImageToGallery(image.outputPath);
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
      for (final outputPath in export.outputPaths) {
        await saveImageToGallery(outputPath);
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

  Future<LocalImageFile> _localImageFromXFile(XFile pickedFile) async {
    final file = File(pickedFile.path);
    if (!file.existsSync()) {
      throw const AppException('图片文件不存在，请重新选择');
    }
    final decoded = await _readImage(file.path);
    final name = pickedFile.name.trim().isNotEmpty
        ? pickedFile.name.trim()
        : _basename(file.path);
    return LocalImageFile(
      path: file.path,
      name: name,
      sizeBytes: await file.length(),
      mimeType: pickedFile.mimeType ?? _mimeTypeForPath(file.path),
      width: decoded.width,
      height: decoded.height,
    );
  }

  Future<img.Image> _readImage(String imagePath) async {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty) {
      throw const AppException('图片路径为空，请重新选择图片');
    }
    final file = File(normalizedPath);
    if (!file.existsSync()) {
      throw const AppException('图片文件不存在，请重新选择');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const AppException('图片文件为空，请重新选择');
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw const AppException('图片格式不支持或文件已损坏');
    }
    if (decoded.width * decoded.height > _maxDecodedPixels) {
      throw const AppException('图片尺寸过大，请先缩小后再处理');
    }
    return decoded;
  }

  Future<File> _createOutputFile({
    required String prefix,
    required String extension,
  }) async {
    final directory = await _createOutputDirectory(prefix);
    final safeExtension = extension.trim().replaceAll('.', '').toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File(
      PlatformPath.join(directory.path, '${prefix}_$timestamp.$safeExtension'),
    );
  }

  Future<Directory> _createOutputDirectory(String prefix) async {
    final root = await _temporaryDirectoryProvider();
    final directory = Directory(
      PlatformPath.join(root.path, 'image_tools_$prefix'),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<File> _writeEncodedImage({
    required img.Image image,
    required String prefix,
    required String extension,
    int quality = 95,
  }) async {
    final output = await _createOutputFile(
      prefix: prefix,
      extension: extension,
    );
    final bytes = switch (extension.toLowerCase()) {
      'jpg' || 'jpeg' => img.encodeJpg(image, quality: quality),
      'bmp' => img.encodeBmp(image),
      _ => img.encodePng(image),
    };
    await output.writeAsBytes(bytes, flush: true);
    return output;
  }

  Future<File> _convertImageFile({
    required LocalImageFile source,
    required String format,
    required int quality,
  }) async {
    final extension = format == 'jpg' ? 'jpg' : format;
    if (format == 'webp') {
      final output = await _createOutputFile(
        prefix: 'converted',
        extension: extension,
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        output.path,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (result == null) {
        throw const AppException('格式转换结果为空，请重试');
      }
      final outputFile = File(result.path);
      if (!outputFile.existsSync()) {
        throw const AppException('导出路径为空，请重试');
      }
      return outputFile;
    }

    final decoded = await _readImage(source.path);
    return _writeEncodedImage(
      image: decoded,
      prefix: 'converted',
      extension: extension,
      quality: quality,
    );
  }

  _ImageRect _cropRect(
    img.Image image, {
    required double aspectRatio,
    double? cropLeftRatio,
    double? cropTopRatio,
  }) {
    final sourceRatio = image.width / image.height;
    var width = image.width;
    var height = image.height;
    if (sourceRatio > aspectRatio) {
      width = (image.height * aspectRatio).round().clamp(1, image.width);
    } else {
      height = (image.width / aspectRatio).round().clamp(1, image.height);
    }
    final left = cropLeftRatio == null
        ? ((image.width - width) / 2).round()
        : (image.width * cropLeftRatio).round();
    final top = cropTopRatio == null
        ? ((image.height - height) / 2).round()
        : (image.height * cropTopRatio).round();
    final safeLeft = left.clamp(0, math.max(0, image.width - width)).toInt();
    final safeTop = top.clamp(0, math.max(0, image.height - height)).toInt();
    return _ImageRect(
      left: safeLeft,
      top: safeTop,
      width: width.clamp(1, image.width - safeLeft).toInt(),
      height: height.clamp(1, image.height - safeTop).toInt(),
    );
  }

  _ImageRect _gridCropRect(
    img.Image image, {
    double? cropLeftRatio,
    double? cropTopRatio,
    double? cropSizeRatio,
  }) {
    final shortestSide = math.min(image.width, image.height);
    var size = shortestSide;
    var left = ((image.width - size) / 2).round();
    var top = ((image.height - size) / 2).round();
    if (cropLeftRatio != null &&
        cropTopRatio != null &&
        cropSizeRatio != null) {
      size = (shortestSide * cropSizeRatio).round().clamp(1, shortestSide);
      left = (image.width * cropLeftRatio).round();
      top = (image.height * cropTopRatio).round();
    }
    left = left.clamp(0, math.max(0, image.width - size));
    top = top.clamp(0, math.max(0, image.height - size));
    return _ImageRect(left: left, top: top, width: size, height: size);
  }

  Future<img.Image> _createTextWatermarkLayer({
    required String text,
    required int fontSize,
    required int opacity,
    required String color,
    required int maxWidth,
  }) async {
    final painter = painting.TextPainter(
      text: painting.TextSpan(
        text: text,
        style: painting.TextStyle(
          color: _uiColorFromHex(color, opacity: opacity),
          fontSize: fontSize.toDouble(),
          fontWeight: painting.FontWeight.w700,
        ),
      ),
      textAlign: painting.TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: math.max(1, maxWidth).toDouble());
    final width = math.max(1, painter.width.ceil());
    final height = math.max(1, painter.height.ceil());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    painter.paint(canvas, ui.Offset.zero);
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width, height);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    rendered.dispose();
    if (byteData == null) {
      throw const AppException('文字水印渲染失败，请重试');
    }
    final layer = img.decodePng(byteData.buffer.asUint8List());
    if (layer == null || layer.width <= 0 || layer.height <= 0) {
      throw const AppException('文字水印渲染结果异常，请重试');
    }
    return layer;
  }

  void _applyFilterToImage(img.Image image, String filter) {
    switch (filter) {
      case 'grayscale':
        img.grayscale(image);
      case 'monochrome':
        img.monochrome(image);
      case 'sepia':
        img.sepia(image);
      case 'invert':
        img.invert(image);
      case 'warm':
        img.adjustColor(image, saturation: 1.12, brightness: 1.04, hue: 6);
      case 'cool':
        img.adjustColor(image, saturation: 0.94, brightness: 1.02, hue: -8);
      case 'hdr':
        img.adjustColor(image, contrast: 1.35, saturation: 1.18);
      case 'film':
        img.sepia(image, amount: 0.35);
        img.adjustColor(image, contrast: 1.08, saturation: 0.82);
      case 'sharpen':
        img.convolution(image, filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0]);
      case 'soften':
        img.smooth(image, weight: 1);
      default:
        throw const AppException('滤镜类型不支持');
    }
  }

  ui.Color _uiColorFromHex(String value, {required int opacity}) {
    final normalized = _normalizeHexColor(value) ?? '#FFFFFF';
    final rgb = int.parse(normalized.substring(1), radix: 16);
    final alpha = WatermarkOpacity.alphaFromPercent(opacity);
    return ui.Color.fromARGB(
      alpha,
      (rgb >> 16) & 0xFF,
      (rgb >> 8) & 0xFF,
      rgb & 0xFF,
    );
  }

  String _mimeTypeForPath(String filePath) {
    final extension = _extension(filePath);
    return _mimeTypeForFormat(extension == 'jpeg' ? 'jpg' : extension);
  }

  String _mimeTypeForFormat(String format) {
    return switch (format.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/*',
    };
  }

  String _extension(String filePath) {
    final name = _basename(filePath);
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1).toLowerCase();
  }

  String _basename(String filePath) {
    final normalized = filePath.replaceAll('/', '\\');
    final index = normalized.lastIndexOf('\\');
    if (index < 0 || index == normalized.length - 1) {
      return normalized.isEmpty ? '未命名图片' : normalized;
    }
    return normalized.substring(index + 1);
  }

  String _messageForGalException(GalException error) {
    return switch (error.type) {
      GalExceptionType.accessDenied => '相册访问权限被拒绝，无法保存图片',
      GalExceptionType.notEnoughSpace => '设备存储空间不足，无法保存图片',
      GalExceptionType.notSupportedFormat => '相册不支持当前图片格式',
      GalExceptionType.unexpected => '保存图片到相册失败，请重试',
    };
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

class _ImageRect {
  const _ImageRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;
}
