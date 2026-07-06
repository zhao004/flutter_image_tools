import 'package:flutter/widgets.dart';

/// 将本地语言设置转换为 Flutter Locale。
///
/// 设计意图：设置仓储只保存稳定字符串；入口和设置页统一通过这里兜底。
/// 返回 null 表示跟随系统，避免非法历史值导致应用启动失败。
Locale? localeFromSetting(String value) {
  return switch (value.trim().toLowerCase()) {
    'zh_cn' => const Locale('zh', 'CN'),
    'zh_tw' => const Locale('zh', 'TW'),
    'en' => const Locale('en'),
    _ => null,
  };
}
