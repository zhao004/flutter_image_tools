/// 应用统一异常，负责把底层异常转换成用户可理解的中文提示。
///
/// 异常策略：业务层只向界面抛出 AppException；未知异常在边界处包装，
/// 既避免泄露底层实现，也保证错误日志能保留原始错误文本。
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
