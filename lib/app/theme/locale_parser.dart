import 'package:flutter/widgets.dart';

/// 应用默认语言，作为设备语言不受支持或设置损坏时的最终兜底。
const Locale defaultAppLocale = Locale('zh', 'CN');

/// 翻译表已注册的语言列表。
///
/// 设计意图：所有入口都复用同一份支持列表，避免启动、本地化代理和设置页
/// 各自维护 Locale 时出现格式不一致。
const List<Locale> supportedAppLocales = <Locale>[
  Locale('zh', 'CN'),
  Locale('zh', 'TW'),
  Locale('en'),
];

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

/// 将设备 Locale 归一化为翻译表已经注册的 Locale。
///
/// 设计意图：部分系统会返回 `zh`、`zh_Hans_CN`、`zh_Hant_HK`、
/// `en_US` 等更细粒度 Locale；GetX 会按完整 key 查找翻译，如果没有
/// 归一化到 `zh_CN`、`zh_TW`、`en`，首启就可能直接显示翻译字段名。
Locale resolveSupportedLocale(Locale? locale) {
  if (locale == null) {
    return defaultAppLocale;
  }

  final languageCode = locale.languageCode.toLowerCase();
  final scriptCode = locale.scriptCode?.toLowerCase();
  final countryCode = locale.countryCode?.toLowerCase();

  if (languageCode == 'zh') {
    final isTraditionalChinese =
        scriptCode == 'hant' ||
        countryCode == 'tw' ||
        countryCode == 'hk' ||
        countryCode == 'mo';
    return isTraditionalChinese ? const Locale('zh', 'TW') : defaultAppLocale;
  }

  if (languageCode == 'en') {
    return const Locale('en');
  }

  return defaultAppLocale;
}

/// 根据本地设置和设备语言解析应用最终使用的 Locale。
///
/// 异常策略：未知设置值按“跟随系统”处理，再统一映射到受支持语言；
/// 这样历史脏数据不会让应用启动到未注册翻译表。
Locale localeFromSettingOrDevice(String value, Locale? deviceLocale) {
  return localeFromSetting(value) ?? resolveSupportedLocale(deviceLocale);
}
