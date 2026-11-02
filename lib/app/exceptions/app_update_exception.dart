/// 自动更新失败类型，用于把网络、资产和安装错误映射为稳定的用户提示。
enum AppUpdateFailureCode {
  network,
  rateLimited,
  invalidResponse,
  unsupportedPlatform,
  unsupportedAbi,
  assetMissing,
  downloadFailed,
  checksumMismatch,
  installPermissionRequired,
  installerUnavailable,
  invalidCurrentVersion,
  unknown,
}

/// 自动更新异常。
///
/// 异常策略：底层网络和平台异常只保留为 cause，界面根据 failureCode
/// 展示本地化提示，避免把系统细节或下载地址暴露给用户。
class AppUpdateException implements Exception {
  const AppUpdateException(this.failureCode, {this.cause});

  final AppUpdateFailureCode failureCode;
  final Object? cause;

  @override
  String toString() => 'AppUpdateException($failureCode)';
}
