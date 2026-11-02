import 'dart:io';

import 'package:flutter/services.dart';

import '../exceptions/app_update_exception.dart';

/// 自动更新所需的 Android 平台能力。
abstract class AppUpdatePlatform {
  bool get isSupported;

  Future<String> getPreferredAbi();

  Future<bool> canInstallPackages();

  Future<void> openInstallPermissionSettings();

  Future<void> installApk(String filePath);
}

/// 通过专用 MethodChannel 与 Android 安装器交互。
///
/// 设计意图：下载和摘要校验保留在 Dart 侧，ABI 查询、未知来源权限和
/// FileProvider 安装交给原生实现，避免依赖长期未维护的安装插件。
class MethodChannelAppUpdatePlatform implements AppUpdatePlatform {
  MethodChannelAppUpdatePlatform({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'image_toolkit/app_update';

  final MethodChannel _channel;

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<String> getPreferredAbi() async {
    if (!isSupported) {
      throw const AppUpdateException(AppUpdateFailureCode.unsupportedPlatform);
    }
    try {
      final abi = await _channel.invokeMethod<String>('getPreferredAbi');
      if (abi == null || abi.trim().isEmpty) {
        throw const AppUpdateException(AppUpdateFailureCode.unsupportedAbi);
      }
      return abi;
    } on AppUpdateException {
      rethrow;
    } on PlatformException catch (error) {
      throw AppUpdateException(
        AppUpdateFailureCode.unsupportedAbi,
        cause: error,
      );
    }
  }

  @override
  Future<bool> canInstallPackages() async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException catch (error) {
      throw AppUpdateException(
        AppUpdateFailureCode.installerUnavailable,
        cause: error,
      );
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    if (!isSupported) {
      throw const AppUpdateException(AppUpdateFailureCode.unsupportedPlatform);
    }
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException catch (error) {
      throw AppUpdateException(
        AppUpdateFailureCode.installerUnavailable,
        cause: error,
      );
    }
  }

  @override
  Future<void> installApk(String filePath) async {
    final normalizedPath = filePath.trim();
    if (!isSupported || normalizedPath.isEmpty) {
      throw const AppUpdateException(AppUpdateFailureCode.installerUnavailable);
    }
    try {
      await _channel.invokeMethod<void>('installApk', <String, Object?>{
        'path': normalizedPath,
      });
    } on PlatformException catch (error) {
      final code = error.code == 'permission_required'
          ? AppUpdateFailureCode.installPermissionRequired
          : AppUpdateFailureCode.installerUnavailable;
      throw AppUpdateException(code, cause: error);
    }
  }
}
