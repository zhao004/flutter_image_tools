import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../exceptions/app_update_exception.dart';
import '../models/app_update_release.dart';
import 'app_update_platform.dart';

typedef AppVersionLoader = Future<String> Function();
typedef UpdateTemporaryDirectoryProvider = Future<Directory> Function();
typedef UpdateProgressCallback =
    void Function(int downloadedBytes, int? totalBytes);

/// GitHub 自动更新服务，负责版本查询、资产选择、下载和摘要校验。
///
/// 设计意图：网络客户端、版本读取和临时目录均可注入，测试不访问真实
/// GitHub；自动更新只接受公开仓库的正式 Release，并由 Android 安装器
/// 在最终安装阶段校验 APK 签名。
class AppUpdateService {
  AppUpdateService({
    required AppUpdatePlatform platform,
    http.Client? client,
    AppVersionLoader? versionLoader,
    UpdateTemporaryDirectoryProvider? temporaryDirectoryProvider,
    Uri? latestReleaseUri,
  }) : _platform = platform,
       _client = client ?? http.Client(),
       _versionLoader =
           versionLoader ??
           (() async => (await PackageInfo.fromPlatform()).version),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _latestReleaseUri =
           latestReleaseUri ??
           Uri.parse(
             'https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/latest',
           );

  static const String repositoryOwner = 'zhao004';
  static const String repositoryName = 'flutter_image_tools';
  static const String checksumAssetName = 'SHA256SUMS.txt';
  static const String _githubApiVersion = '2022-11-28';
  static const Duration _metadataTimeout = Duration(seconds: 15);
  static const Duration _streamIdleTimeout = Duration(seconds: 30);
  static const int maxApkBytes = 200 * 1024 * 1024;
  static const int maxChecksumBytes = 256 * 1024;
  static const Set<String> supportedAbis = {
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
  };

  final AppUpdatePlatform _platform;
  final http.Client _client;
  final AppVersionLoader _versionLoader;
  final UpdateTemporaryDirectoryProvider _temporaryDirectoryProvider;
  final Uri _latestReleaseUri;

  bool get isSupported => _platform.isSupported;

  /// 读取当前安装包版本，失败时转换为更新业务异常。
  Future<String> loadCurrentVersion() async {
    try {
      final version = (await _versionLoader()).trim();
      if (tryParseAppUpdateVersion(version) == null) {
        throw const AppUpdateException(
          AppUpdateFailureCode.invalidCurrentVersion,
        );
      }
      return version;
    } on AppUpdateException {
      rethrow;
    } catch (error) {
      throw AppUpdateException(
        AppUpdateFailureCode.invalidCurrentVersion,
        cause: error,
      );
    }
  }

  /// 查询 GitHub 最新正式 Release。
  ///
  /// 仅当远端版本高于当前版本时才解析 ABI 并返回可更新资产。
  Future<AppUpdateCheckResult> checkForUpdate({String? currentVersion}) async {
    if (!isSupported) {
      throw const AppUpdateException(AppUpdateFailureCode.unsupportedPlatform);
    }
    final installedVersion = (currentVersion ?? await loadCurrentVersion())
        .trim();
    final parsedCurrentVersion = tryParseAppUpdateVersion(installedVersion);
    if (parsedCurrentVersion == null) {
      throw const AppUpdateException(
        AppUpdateFailureCode.invalidCurrentVersion,
      );
    }

    final response = await _sendMetadataRequest(_latestReleaseUri);
    if (response.statusCode == HttpStatus.notFound) {
      return AppUpdateCheckResult(
        currentVersion: installedVersion,
        latestVersion: null,
        release: null,
        preferredAbi: null,
      );
    }
    if (response.statusCode == HttpStatus.forbidden ||
        response.statusCode == 429) {
      throw const AppUpdateException(AppUpdateFailureCode.rateLimited);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException(
        AppUpdateFailureCode.invalidResponse,
        cause: 'GitHub API HTTP ${response.statusCode}',
      );
    }

    final AppUpdateRelease release;
    try {
      final decoded = jsonDecode(
        await _readResponseText(response, maxBytes: 1024 * 1024),
      );
      if (decoded is! Map) {
        throw const FormatException('GitHub Release 响应不是对象');
      }
      release = AppUpdateRelease.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
    } on AppUpdateException {
      rethrow;
    } catch (error) {
      throw AppUpdateException(
        AppUpdateFailureCode.invalidResponse,
        cause: error,
      );
    }

    if (!release.isStable) {
      throw const AppUpdateException(AppUpdateFailureCode.invalidResponse);
    }
    final latestVersion = release.version!;
    if (latestVersion.compareTo(parsedCurrentVersion) <= 0) {
      return AppUpdateCheckResult(
        currentVersion: installedVersion,
        latestVersion: release.versionText,
        release: null,
        preferredAbi: null,
      );
    }

    final preferredAbi = await _platform.getPreferredAbi();
    if (!supportedAbis.contains(preferredAbi)) {
      throw const AppUpdateException(AppUpdateFailureCode.unsupportedAbi);
    }
    final expectedAssetName =
        'imagetoolkit-${release.tagName}-$preferredAbi.apk';
    final asset = release.assetNamed(expectedAssetName);
    if (asset == null || asset.sizeBytes <= 0) {
      throw const AppUpdateException(AppUpdateFailureCode.assetMissing);
    }
    _validateAssetUri(asset.downloadUrl);

    return AppUpdateCheckResult(
      currentVersion: installedVersion,
      latestVersion: release.versionText,
      release: release,
      preferredAbi: preferredAbi,
    );
  }

  /// 下载 APK 和 SHA256SUMS.txt，校验成功后返回缓存中的安装包路径。
  Future<AppUpdateDownload> downloadAndVerify({
    required AppUpdateRelease release,
    required AppUpdateAsset asset,
    UpdateProgressCallback? onProgress,
    VoidCallback? onVerifying,
  }) async {
    final expectedAssetName =
        'imagetoolkit-${release.tagName}-${await _platform.getPreferredAbi()}.apk';
    if (asset.name != expectedAssetName ||
        asset.name.contains('/') ||
        asset.name.contains(r'\')) {
      throw const AppUpdateException(AppUpdateFailureCode.assetMissing);
    }
    _validateAssetUri(asset.downloadUrl);
    final checksumAsset = release.assetNamed(checksumAssetName);
    if (checksumAsset == null) {
      throw const AppUpdateException(AppUpdateFailureCode.assetMissing);
    }
    _validateAssetUri(checksumAsset.downloadUrl);

    final checksumText = await _downloadSmallText(
      checksumAsset.downloadUrl,
      maxBytes: maxChecksumBytes,
    );
    final expectedHash = _parseChecksum(checksumText, asset.name);
    if (expectedHash == null) {
      throw const AppUpdateException(AppUpdateFailureCode.checksumMismatch);
    }

    final cacheDirectory = await _temporaryDirectoryProvider();
    final updateDirectory = Directory(
      '${cacheDirectory.path}${Platform.pathSeparator}updates',
    );
    await updateDirectory.create(recursive: true);
    final targetFile = File(
      '${updateDirectory.path}${Platform.pathSeparator}${asset.name}',
    );
    final partialFile = File('${targetFile.path}.part');
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    if (await partialFile.exists()) {
      await partialFile.delete();
    }

    var downloadedBytes = 0;
    int? totalBytes;
    try {
      final response = await _sendDownloadRequest(
        asset.downloadUrl,
        maxBytes: maxApkBytes,
      );
      totalBytes = response.contentLength != null && response.contentLength! > 0
          ? response.contentLength!
          : asset.sizeBytes;
      if (totalBytes > maxApkBytes || asset.sizeBytes > maxApkBytes) {
        throw const AppUpdateException(AppUpdateFailureCode.downloadFailed);
      }

      final sink = partialFile.openWrite();
      try {
        await for (final chunk in response.stream.timeout(_streamIdleTimeout)) {
          downloadedBytes += chunk.length;
          if (downloadedBytes > maxApkBytes) {
            throw const AppUpdateException(AppUpdateFailureCode.downloadFailed);
          }
          sink.add(chunk);
          onProgress?.call(downloadedBytes, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (downloadedBytes <= 0 ||
          (asset.sizeBytes > 0 && downloadedBytes != asset.sizeBytes) ||
          (response.contentLength != null &&
              response.contentLength! > 0 &&
              downloadedBytes != response.contentLength)) {
        throw const AppUpdateException(AppUpdateFailureCode.downloadFailed);
      }

      onVerifying?.call();
      final digest = await sha256.bind(partialFile.openRead()).first;
      if (digest.toString().toLowerCase() != expectedHash) {
        throw const AppUpdateException(AppUpdateFailureCode.checksumMismatch);
      }
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await partialFile.rename(targetFile.path);
      return AppUpdateDownload(
        filePath: targetFile.path,
        sizeBytes: downloadedBytes,
        sha256: digest.toString().toLowerCase(),
      );
    } on AppUpdateException {
      await _deleteIfExists(partialFile);
      rethrow;
    } on TimeoutException catch (error) {
      await _deleteIfExists(partialFile);
      throw AppUpdateException(AppUpdateFailureCode.network, cause: error);
    } on http.ClientException catch (error) {
      await _deleteIfExists(partialFile);
      throw AppUpdateException(AppUpdateFailureCode.network, cause: error);
    } catch (error) {
      await _deleteIfExists(partialFile);
      throw AppUpdateException(
        AppUpdateFailureCode.downloadFailed,
        cause: error,
      );
    }
  }

  Future<bool> canInstallPackages() => _platform.canInstallPackages();

  Future<void> openInstallPermissionSettings() {
    return _platform.openInstallPermissionSettings();
  }

  Future<void> installApk(String filePath) => _platform.installApk(filePath);

  void close() {
    _client.close();
  }

  Future<http.StreamedResponse> _sendMetadataRequest(Uri uri) {
    return _sendRequest(
      uri,
      headers: const <String, String>{
        HttpHeaders.acceptHeader: 'application/vnd.github+json',
        'X-GitHub-Api-Version': _githubApiVersion,
      },
    );
  }

  Future<http.StreamedResponse> _sendDownloadRequest(
    Uri uri, {
    required int maxBytes,
  }) async {
    final response = await _sendRequest(
      uri,
      headers: const <String, String>{
        HttpHeaders.acceptHeader: 'application/octet-stream',
      },
    );
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException(
        AppUpdateFailureCode.downloadFailed,
        cause: '下载 HTTP ${response.statusCode}',
      );
    }
    if (response.contentLength != null && response.contentLength! > maxBytes) {
      throw const AppUpdateException(AppUpdateFailureCode.downloadFailed);
    }
    return response;
  }

  Future<http.StreamedResponse> _sendRequest(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(<String, String>{
        HttpHeaders.userAgentHeader:
            'ImageToolKit/${await loadCurrentVersion()}',
        ...headers,
      });
      return await _client.send(request).timeout(_metadataTimeout);
    } on TimeoutException catch (error) {
      throw AppUpdateException(AppUpdateFailureCode.network, cause: error);
    } on http.ClientException catch (error) {
      throw AppUpdateException(AppUpdateFailureCode.network, cause: error);
    } catch (error) {
      if (error is AppUpdateException) {
        rethrow;
      }
      throw AppUpdateException(AppUpdateFailureCode.network, cause: error);
    }
  }

  Future<String> _downloadSmallText(Uri uri, {required int maxBytes}) async {
    final response = await _sendRequest(uri);
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException(
        AppUpdateFailureCode.invalidResponse,
        cause: '校验文件 HTTP ${response.statusCode}',
      );
    }
    try {
      return await _readResponseText(response, maxBytes: maxBytes);
    } on AppUpdateException {
      rethrow;
    } catch (error) {
      throw AppUpdateException(
        AppUpdateFailureCode.invalidResponse,
        cause: error,
      );
    }
  }

  Future<String> _readResponseText(
    http.StreamedResponse response, {
    required int maxBytes,
  }) async {
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(_streamIdleTimeout)) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const AppUpdateException(AppUpdateFailureCode.invalidResponse);
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  String? _parseChecksum(String content, String assetName) {
    for (final line in const LineSplitter().convert(content)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) {
        continue;
      }
      final hash = parts.first.toLowerCase();
      var fileName = parts[1];
      if (fileName.startsWith('*')) {
        fileName = fileName.substring(1);
      }
      if (fileName.startsWith('./')) {
        fileName = fileName.substring(2);
      }
      if (fileName == assetName && RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        return hash;
      }
    }
    return null;
  }

  void _validateAssetUri(Uri uri) {
    final expectedPrefix =
        '/$repositoryOwner/$repositoryName/releases/download/';
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        !uri.path.startsWith(expectedPrefix)) {
      throw const AppUpdateException(AppUpdateFailureCode.assetMissing);
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 清理失败不应覆盖原始下载错误；缓存目录可由系统后续回收。
    }
  }
}
