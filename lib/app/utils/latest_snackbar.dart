import 'package:get/get.dart';

/// 显示最新提示，避免多个 Snackbar 按队列连续弹出。
///
/// 设计意图：提示属于即时状态反馈，新提示出现时应替换旧提示，避免用户
/// 看到过期状态；关闭旧提示失败时继续展示新提示，保证关键反馈不丢失。
void showLatestSnackbar(String title, String message) {
  try {
    Get.closeAllSnackbars();
  } catch (_) {
    // 关闭旧提示失败不阻断新提示展示，避免异常导致用户没有反馈。
  }
  Get.snackbar(title, message);
}
