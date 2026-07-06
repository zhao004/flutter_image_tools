import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../repositories/app_settings_repository.dart';
import '../../theme/locale_parser.dart';
import '../../theme/theme_mode_parser.dart';

/// 设置控制器，承载默认压缩参数、导出格式、保存规则、语言和主题模式。
///
/// 异常策略：读取失败回退安全默认值并提示用户；写入失败保留当前界面值，
/// 避免本地数据库异常导致设置页不可用。
class SettingsController extends GetxController {
  SettingsController({required AppSettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  final AppSettingsRepository _settingsRepository;

  final defaultQuality = 80.obs;
  final defaultExportFormat = 'jpg'.obs;
  final defaultSaveRule = 'timestamp'.obs;
  final themeMode = 'system'.obs;
  final language = 'system'.obs;
  final defaultExportDirectory = RxnString();
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    isLoading.value = true;
    try {
      defaultQuality.value = await _settingsRepository.getDefaultQuality();
      defaultExportFormat.value = await _settingsRepository
          .getDefaultExportFormat();
      defaultSaveRule.value = await _settingsRepository.getDefaultSaveRule();
      themeMode.value = await _settingsRepository.getThemeMode();
      language.value = await _settingsRepository.getLanguage();
      defaultExportDirectory.value = await _settingsRepository
          .getDefaultExportDirectory();
    } catch (_) {
      Get.snackbar('读取设置失败', '已使用默认设置');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateDefaultQuality(double value) async {
    final nextValue = value.round().clamp(1, 100);
    defaultQuality.value = nextValue;
    try {
      await _settingsRepository.setDefaultQuality(nextValue);
    } catch (_) {
      Get.snackbar('保存失败', '默认压缩质量未保存');
    }
  }

  Future<void> updateDefaultExportFormat(String format) async {
    try {
      await _settingsRepository.setDefaultExportFormat(format);
      defaultExportFormat.value = format;
    } catch (_) {
      Get.snackbar('保存失败', '默认导出格式未保存');
    }
  }

  Future<void> updateDefaultSaveRule(String rule) async {
    try {
      await _settingsRepository.setDefaultSaveRule(rule);
      defaultSaveRule.value = rule;
    } catch (_) {
      Get.snackbar('保存失败', '默认保存规则未保存');
    }
  }

  Future<void> updateThemeMode(String mode) async {
    try {
      await _settingsRepository.setThemeMode(mode);
      themeMode.value = mode;
      Get.changeThemeMode(themeModeFromSetting(mode));
    } catch (_) {
      Get.snackbar('保存失败', '主题模式未保存');
    }
  }

  Future<void> updateLanguage(String value) async {
    try {
      await _settingsRepository.setLanguage(value);
      language.value = value;
      final locale = localeFromSetting(value);
      if (locale == null) {
        Get.updateLocale(Get.deviceLocale ?? const Locale('zh', 'CN'));
        return;
      }
      Get.updateLocale(locale);
    } catch (_) {
      Get.snackbar('保存失败', '语言设置未保存');
    }
  }
}
