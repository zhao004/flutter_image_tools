import 'package:flutter/services.dart';

import '../core/exceptions/app_exception.dart';
import '../core/models/compressed_image_file.dart';
import '../core/models/converted_image_file.dart';
import '../core/models/cropped_image_file.dart';
import '../core/models/filtered_image_file.dart';
import '../core/models/flipped_image_file.dart';
import '../core/models/local_image_file.dart';
import '../core/models/merged_image_file.dart';
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
  static const Set<String> supportedFilters = {
    'grayscale',
    'monochrome',
    'sepia',
    'invert',
    'warm',
    'cool',
  };
  static const Set<String> supportedConvertFormats = {
    'jpg',
    'png',
    'webp',
    'bmp',
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

  String _messageForCode(String code) {
    return switch (code) {
      'file_not_found' => '图片文件不存在，请重新选择',
      'invalid_image' => '图片格式不支持或文件已损坏',
      'invalid_args' => '图片处理参数无效，请检查后重试',
      'export_failed' => '导出图片失败，请检查存储空间',
      'activity_missing' => '当前设备没有可用的图片选择器',
      'busy' => '已有图片任务正在进行，请稍后再试',
      _ => '图片处理失败，请重试',
    };
  }
}
