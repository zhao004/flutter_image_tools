import 'package:flutter/services.dart';

import '../core/exceptions/app_exception.dart';
import '../core/models/compressed_image_file.dart';
import '../core/models/local_image_file.dart';

/// Android 本地图片能力通道，封装选择图片和压缩图片的原生调用。
///
/// 设计意图：第一阶段不引入额外 Flutter 插件，先用原生平台能力形成离线
/// 闭环；所有 PlatformException 在此转换为 AppException，界面无需感知
/// MethodChannel 细节。
class LocalImageChannel {
  LocalImageChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'image_toolkit/local_image';

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
        <String, Object?>{
          'path': source.path,
          'quality': quality,
        },
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

  String _messageForCode(String code) {
    return switch (code) {
      'file_not_found' => '图片文件不存在，请重新选择',
      'invalid_image' => '图片格式不支持或文件已损坏',
      'export_failed' => '导出图片失败，请检查存储空间',
      'activity_missing' => '当前设备没有可用的图片选择器',
      'busy' => '已有图片任务正在进行，请稍后再试',
      _ => '图片处理失败，请重试',
    };
  }
}
