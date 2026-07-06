import 'dart:convert';

import '../database/database.dart';

/// 应用设置仓储，统一读写本地 app_settings 表。
///
/// 设计意图：设置以 key/value 持久化，后续新增语言、导出目录、保存规则时
/// 不需要频繁迁移表结构；读取时提供安全默认值，避免空库导致页面异常。
class AppSettingsRepository {
  AppSettingsRepository({required AppDatabase database}) : _database = database;

  static const String defaultQualityKey = 'default_quality';
  static const String defaultExportFormatKey = 'default_export_format';
  static const String defaultExportDirectoryKey = 'default_export_directory';
  static const String defaultSaveRuleKey = 'default_save_rule';
  static const String themeModeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String recentToolRoutesKey = 'recent_tool_routes';
  static const int maxRecentToolRoutes = 8;

  final AppDatabase _database;

  Future<int> getDefaultQuality() async {
    final value = await _getInt(defaultQualityKey);
    return (value ?? 80).clamp(1, 100);
  }

  Future<void> setDefaultQuality(int quality) async {
    final normalized = quality.clamp(1, 100);
    await _setValue(defaultQualityKey, normalized.toString(), 'int');
  }

  Future<String> getDefaultExportFormat() async {
    return await _getString(defaultExportFormatKey) ?? 'jpg';
  }

  Future<void> setDefaultExportFormat(String format) async {
    final normalized = format.trim().toLowerCase();
    final supportedFormats = {'jpg', 'png', 'webp'};
    if (!supportedFormats.contains(normalized)) {
      throw ArgumentError.value(format, 'format', '不支持的默认导出格式');
    }
    await _setValue(defaultExportFormatKey, normalized, 'string');
  }

  Future<String?> getDefaultExportDirectory() {
    return _getString(defaultExportDirectoryKey);
  }

  Future<void> setDefaultExportDirectory(String directory) async {
    final normalized = directory.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(directory, 'directory', '默认导出目录不能为空');
    }
    await _setValue(defaultExportDirectoryKey, normalized, 'string');
  }

  Future<String> getDefaultSaveRule() async {
    return await _getString(defaultSaveRuleKey) ?? 'timestamp';
  }

  Future<void> setDefaultSaveRule(String rule) async {
    final normalized = rule.trim().toLowerCase();
    final supportedRules = {'timestamp', 'source_name', 'feature_folder'};
    if (!supportedRules.contains(normalized)) {
      throw ArgumentError.value(rule, 'rule', '不支持的默认保存规则');
    }
    await _setValue(defaultSaveRuleKey, normalized, 'string');
  }

  Future<String> getThemeMode() async {
    return await _getString(themeModeKey) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final normalized = mode.trim().toLowerCase();
    final supportedModes = {'system', 'light', 'dark'};
    if (!supportedModes.contains(normalized)) {
      throw ArgumentError.value(mode, 'mode', '不支持的主题模式');
    }
    await _setValue(themeModeKey, normalized, 'string');
  }

  Future<String> getLanguage() async {
    return await _getString(languageKey) ?? 'system';
  }

  Future<void> setLanguage(String language) async {
    final normalized = language.trim().toLowerCase();
    final supportedLanguages = {'system', 'zh_cn', 'zh_tw', 'en'};
    if (!supportedLanguages.contains(normalized)) {
      throw ArgumentError.value(language, 'language', '不支持的语言设置');
    }
    await _setValue(languageKey, normalized, 'string');
  }

  Future<List<String>> getRecentToolRoutes() async {
    final value = await _getString(recentToolRoutesKey);
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<String>()
        .map((route) => route.trim())
        .where((route) => route.isNotEmpty)
        .take(maxRecentToolRoutes)
        .toList(growable: false);
  }

  Future<void> setRecentToolRoutes(List<String> routes) async {
    final normalized = <String>[];
    for (final route in routes) {
      final value = route.trim();
      if (value.isEmpty || normalized.contains(value)) {
        continue;
      }
      normalized.add(value);
      if (normalized.length >= maxRecentToolRoutes) {
        break;
      }
    }
    await _setValue(recentToolRoutesKey, jsonEncode(normalized), 'json');
  }

  Future<int?> _getInt(String key) async {
    final value = await _getString(key);
    if (value == null) {
      return null;
    }
    return int.tryParse(value);
  }

  Future<String?> _getString(String key) async {
    final setting = await _database.getSetting(key);
    return setting?.settingValue;
  }

  Future<void> _setValue(String key, String value, String type) async {
    await _database.upsertSetting(
      AppSettingsCompanion.insert(
        settingKey: key,
        settingValue: value,
        valueType: type,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
