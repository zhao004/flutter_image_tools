import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 显示最新 Toast，避免多个提示按队列连续弹出。
///
/// 设计意图：提示属于即时状态反馈，新提示出现时应替换旧提示，避免用户
/// 看到过期状态；关闭旧提示失败时继续展示新提示，保证关键反馈不丢失。
void showLatestSnackbar(String title, String message) {
  try {
    Fluttertoast.cancel();
  } catch (_) {
    // 关闭旧提示失败不阻断新提示展示，避免异常导致用户没有反馈。
  }
  final normalizedTitle = title.trim();
  final normalizedMessage = message.trim();
  final text = normalizedTitle.isEmpty
      ? normalizedMessage
      : '$normalizedTitle\n$normalizedMessage';
  Fluttertoast.showToast(
    msg: text,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 2,
    backgroundColor: Colors.black87,
    textColor: Colors.white,
    fontSize: 14,
  );
}
