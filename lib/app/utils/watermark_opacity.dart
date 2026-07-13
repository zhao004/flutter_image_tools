/// 水印透明度换算工具，统一预览与导出使用的百分比和 8 位 Alpha 规则。
///
/// 控制器会把用户输入限制在 10% 到 100%；底层仍收敛到 0% 到 100%，用于防御
/// 损坏参数和独立服务调用。所有换算均采用四舍五入，避免不同渲染链路相差一个色阶。
class WatermarkOpacity {
  const WatermarkOpacity._();

  static const int minimumPercent = 0;
  static const int maximumPercent = 100;
  static const int maximumAlpha = 255;

  static int normalizePercent(int percent) {
    return percent.clamp(minimumPercent, maximumPercent);
  }

  static double factorFromPercent(int percent) {
    return normalizePercent(percent) / maximumPercent;
  }

  static int alphaFromPercent(int percent) {
    return (factorFromPercent(percent) * maximumAlpha).round();
  }

  static double scaleNormalizedAlpha(num sourceAlpha, int percent) {
    final safeSourceAlpha = sourceAlpha.isFinite
        ? sourceAlpha.clamp(0, 1).toDouble()
        : 0.0;
    return safeSourceAlpha * factorFromPercent(percent);
  }

  static int scaleAlpha(num sourceAlpha, int percent) {
    final safeSourceAlpha = sourceAlpha.isFinite
        ? sourceAlpha.clamp(0, maximumAlpha).toDouble()
        : 0.0;
    return (scaleNormalizedAlpha(safeSourceAlpha / maximumAlpha, percent) *
            maximumAlpha)
        .round();
  }
}
