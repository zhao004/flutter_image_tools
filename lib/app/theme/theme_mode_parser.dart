import 'package:flutter/material.dart';

/// 将本地设置字符串转换为 Flutter 主题模式。
///
/// 设计意图：仓储层只持久化简单字符串，入口和设置页通过同一转换函数
/// 做边界兜底，避免非法历史值导致启动或运行期切换失败。
ThemeMode themeModeFromSetting(String value) {
  return switch (value.trim().toLowerCase()) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
