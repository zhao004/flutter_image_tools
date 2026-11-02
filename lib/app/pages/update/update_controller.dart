import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../exceptions/app_update_exception.dart';
import '../../models/app_update_release.dart';
import '../../repositories/app_settings_repository.dart';
import '../../services/app_update_service.dart';

/// 更新页面及启动检查共享的阶段状态。
enum AppUpdatePhase {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  verifying,
  installing,
  installPermissionRequired,
  installReady,
  installerOpened,
  error,
  unsupported,
}

/// 全局自动更新控制器，负责节流、持久化、下载和安装状态。
///
/// 设计意图：控制器由 InitialBinding 注册，首页自动检查与更新页共享同一
/// 状态；网络失败在自动检查时静默处理，在用户主动检查或下载时保留错误。
class AppUpdateController extends GetxController with WidgetsBindingObserver {
  AppUpdateController({
    required AppUpdateService service,
    required AppSettingsRepository settingsRepository,
    required bool automaticChecksEnabled,
    DateTime Function()? clock,
  }) : _service = service,
       _settingsRepository = settingsRepository,
       _automaticChecksEnabled = automaticChecksEnabled,
       _clock = clock ?? DateTime.now;

  static const Duration automaticCheckInterval = Duration(hours: 24);

  final AppUpdateService _service;
  final AppSettingsRepository _settingsRepository;
  final bool _automaticChecksEnabled;
  final DateTime Function() _clock;

  final phase = AppUpdatePhase.idle.obs;
  final currentVersion = ''.obs;
  final latestVersion = RxnString();
  final preferredAbi = RxnString();
  final availableRelease = Rxn<AppUpdateRelease>();
  final failureCode = Rxn<AppUpdateFailureCode>();
  final lastCheckedAt = Rxn<DateTime>();
  final progress = 0.0.obs;
  final downloadedBytes = 0.obs;
  final totalBytes = 0.obs;
  final canInstallPackages = false.obs;

  Future<void>? _initializationFuture;
  String? _downloadedFilePath;
  bool _automaticCheckAttempted = false;
  bool _checking = false;
  bool _downloading = false;

  bool get isSupported => _service.isSupported;

  bool get hasDownloadedFile => _downloadedFilePath != null;

  bool get isBusy => switch (phase.value) {
    AppUpdatePhase.checking ||
    AppUpdatePhase.downloading ||
    AppUpdatePhase.verifying ||
    AppUpdatePhase.installing => true,
    _ => false,
  };

  String get errorMessage {
    return switch (failureCode.value) {
      AppUpdateFailureCode.network => 'update.error.network'.tr,
      AppUpdateFailureCode.rateLimited => 'update.error.rateLimited'.tr,
      AppUpdateFailureCode.invalidResponse => 'update.error.invalidResponse'.tr,
      AppUpdateFailureCode.unsupportedPlatform =>
        'update.error.unsupportedPlatform'.tr,
      AppUpdateFailureCode.unsupportedAbi => 'update.error.unsupportedAbi'.tr,
      AppUpdateFailureCode.assetMissing => 'update.error.assetMissing'.tr,
      AppUpdateFailureCode.downloadFailed => 'update.error.downloadFailed'.tr,
      AppUpdateFailureCode.checksumMismatch =>
        'update.error.checksumMismatch'.tr,
      AppUpdateFailureCode.installPermissionRequired =>
        'update.permission.required'.tr,
      AppUpdateFailureCode.installerUnavailable =>
        'update.error.installerUnavailable'.tr,
      AppUpdateFailureCode.invalidCurrentVersion =>
        'update.error.invalidCurrentVersion'.tr,
      AppUpdateFailureCode.unknown || null => 'update.error.unknown'.tr,
    };
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(initialize());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.close();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        phase.value == AppUpdatePhase.installPermissionRequired) {
      unawaited(refreshInstallPermission());
    }
  }

  Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (!_service.isSupported) {
      phase.value = AppUpdatePhase.unsupported;
      return;
    }
    try {
      currentVersion.value = await _service.loadCurrentVersion();
    } on AppUpdateException catch (error) {
      _setFailure(error);
    } catch (_) {
      _setFailure(
        const AppUpdateException(AppUpdateFailureCode.invalidCurrentVersion),
      );
    }
    await refreshInstallPermission(updatePhase: false);
  }

  /// 首页启动时调用；仅在 release 构建、超过 24 小时且未被暂缓时返回版本。
  Future<AppUpdateRelease?> checkAutomatically() async {
    if (!_automaticChecksEnabled || _automaticCheckAttempted) {
      return null;
    }
    _automaticCheckAttempted = true;
    await initialize();
    if (!_service.isSupported || _checking) {
      return null;
    }

    final now = _clock().toUtc();
    try {
      final persistedLastCheck = await _settingsRepository
          .getLastUpdateCheckAt();
      lastCheckedAt.value = persistedLastCheck;
      if (persistedLastCheck != null &&
          now.isAfter(persistedLastCheck) &&
          now.difference(persistedLastCheck) < automaticCheckInterval) {
        return null;
      }
    } catch (_) {
      // 本地节流读取失败时仍允许检查，不能因设置库异常丢失更新能力。
    }

    try {
      final result = await _runCheck(checkedAt: now);
      final release = result.release;
      if (release == null) {
        return null;
      }
      final dismissedVersion = await _settingsRepository
          .getDismissedUpdateVersion();
      return dismissedVersion == release.versionText ? null : release;
    } catch (_) {
      if (phase.value == AppUpdatePhase.error) {
        phase.value = AppUpdatePhase.idle;
        failureCode.value = null;
      }
      return null;
    }
  }

  /// 用户主动检查；始终绕过节流，并把失败状态保留在页面。
  Future<void> checkForUpdates() async {
    await initialize();
    if (!_service.isSupported || _checking) {
      return;
    }
    try {
      await _runCheck(checkedAt: _clock().toUtc());
    } catch (_) {
      // 错误通过 phase/failureCode 暴露给页面。
    }
  }

  /// 暂缓版本，后续自动检查不会再提示同一版本。
  Future<void> postponeCurrentUpdate() async {
    final release = availableRelease.value;
    if (release == null) {
      return;
    }
    try {
      await _settingsRepository.setDismissedUpdateVersion(release.versionText);
    } catch (_) {
      // 暂缓偏好写入失败不应阻断用户继续使用当前版本。
    }
  }

  /// 下载当前 ABI 的 APK，校验后直接进入权限检查或系统安装器。
  Future<void> downloadAndInstall() async {
    if (_downloading || phase.value == AppUpdatePhase.installing) {
      return;
    }
    final release = availableRelease.value;
    final abi = preferredAbi.value;
    if (release == null || abi == null || abi.isEmpty) {
      _setFailure(const AppUpdateException(AppUpdateFailureCode.assetMissing));
      return;
    }
    final assetName = 'imagetoolkit-${release.tagName}-$abi.apk';
    final asset = release.assetNamed(assetName);
    if (asset == null) {
      _setFailure(const AppUpdateException(AppUpdateFailureCode.assetMissing));
      return;
    }

    _downloading = true;
    _downloadedFilePath = null;
    failureCode.value = null;
    phase.value = AppUpdatePhase.downloading;
    progress.value = 0;
    downloadedBytes.value = 0;
    totalBytes.value = asset.sizeBytes;
    try {
      final download = await _service.downloadAndVerify(
        release: release,
        asset: asset,
        onProgress: (received, total) {
          downloadedBytes.value = received;
          totalBytes.value = total ?? asset.sizeBytes;
          progress.value = totalBytes.value > 0
              ? (received / totalBytes.value).clamp(0.0, 1.0)
              : 0.0;
        },
        onVerifying: () {
          phase.value = AppUpdatePhase.verifying;
        },
      );
      _downloadedFilePath = download.filePath;
      downloadedBytes.value = download.sizeBytes;
      totalBytes.value = download.sizeBytes;
      progress.value = 1;

      final allowed = await _service.canInstallPackages();
      canInstallPackages.value = allowed;
      if (!allowed) {
        phase.value = AppUpdatePhase.installPermissionRequired;
        return;
      }
      await installDownloaded();
    } on AppUpdateException catch (error) {
      _setFailure(error);
    } catch (_) {
      _setFailure(
        const AppUpdateException(AppUpdateFailureCode.downloadFailed),
      );
    } finally {
      _downloading = false;
    }
  }

  /// 重新检查未知应用安装权限，授权后停留在待安装状态。
  Future<void> refreshInstallPermission({bool updatePhase = true}) async {
    if (!_service.isSupported) {
      return;
    }
    try {
      final allowed = await _service.canInstallPackages();
      canInstallPackages.value = allowed;
      if (updatePhase &&
          phase.value == AppUpdatePhase.installPermissionRequired) {
        phase.value = allowed
            ? AppUpdatePhase.installReady
            : AppUpdatePhase.installPermissionRequired;
      }
    } catch (error) {
      if (updatePhase) {
        _setFailure(
          error is AppUpdateException
              ? error
              : const AppUpdateException(
                  AppUpdateFailureCode.installerUnavailable,
                ),
        );
      }
    }
  }

  /// 打开发当前应用的“安装未知应用”系统权限页。
  Future<void> openInstallPermissionSettings() async {
    try {
      await _service.openInstallPermissionSettings();
    } on AppUpdateException catch (error) {
      _setFailure(error);
    } catch (_) {
      _setFailure(
        const AppUpdateException(AppUpdateFailureCode.installerUnavailable),
      );
    }
  }

  /// 调起系统安装器；权限缺失时停留在明确的授权阶段。
  Future<void> installDownloaded() async {
    final filePath = _downloadedFilePath;
    if (filePath == null || filePath.isEmpty) {
      return;
    }
    failureCode.value = null;
    try {
      final allowed = await _service.canInstallPackages();
      canInstallPackages.value = allowed;
      if (!allowed) {
        phase.value = AppUpdatePhase.installPermissionRequired;
        return;
      }
      phase.value = AppUpdatePhase.installing;
      await _service.installApk(filePath);
      phase.value = AppUpdatePhase.installerOpened;
    } on AppUpdateException catch (error) {
      _setFailure(error);
    } catch (_) {
      _setFailure(
        const AppUpdateException(AppUpdateFailureCode.installerUnavailable),
      );
    }
  }

  Future<AppUpdateCheckResult> _runCheck({required DateTime checkedAt}) async {
    _checking = true;
    failureCode.value = null;
    phase.value = AppUpdatePhase.checking;
    try {
      final result = await _service.checkForUpdate(
        currentVersion: currentVersion.value.isEmpty
            ? null
            : currentVersion.value,
      );
      currentVersion.value = result.currentVersion;
      latestVersion.value = result.latestVersion;
      preferredAbi.value = result.preferredAbi;
      lastCheckedAt.value = checkedAt;
      await _persistLastCheck(checkedAt);

      final release = result.release;
      if (release == null) {
        availableRelease.value = null;
        _downloadedFilePath = null;
        phase.value = AppUpdatePhase.upToDate;
      } else {
        availableRelease.value = release;
        _downloadedFilePath = null;
        phase.value = AppUpdatePhase.updateAvailable;
      }
      return result;
    } on AppUpdateException catch (error) {
      _setFailure(error);
      rethrow;
    } catch (error) {
      _setFailure(
        AppUpdateException(AppUpdateFailureCode.unknown, cause: error),
      );
      rethrow;
    } finally {
      _checking = false;
    }
  }

  Future<void> _persistLastCheck(DateTime checkedAt) async {
    try {
      await _settingsRepository.setLastUpdateCheckAt(checkedAt);
    } catch (_) {
      // 检查结果仍可在当前会话使用，持久化失败仅影响下次启动节流。
    }
  }

  void _setFailure(AppUpdateException error) {
    failureCode.value = error.failureCode;
    phase.value = AppUpdatePhase.error;
  }
}
