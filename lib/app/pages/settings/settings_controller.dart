import 'package:get/get.dart';

/// 设置控制器，承载第一阶段默认压缩参数和离线说明。
///
/// 后续会把设置写入 Drift 的 app_settings 表；当前先保留响应式状态，
/// 保证设置页和压缩页可以逐步解耦。
class SettingsController extends GetxController {
  final defaultQuality = 80.obs;

  void updateDefaultQuality(double value) {
    defaultQuality.value = value.round().clamp(1, 100);
  }
}
