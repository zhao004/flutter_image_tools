import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/database/database.dart';
import 'app/repositories/app_settings_repository.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/app_translations.dart';
import 'app/theme/locale_parser.dart';
import 'app/theme/theme_mode_parser.dart';

/// 启动阶段应用设置，集中保存主题和语言偏好。
///
/// 设计意图：入口只读取一次本地数据库，避免主题和语言分别建立临时连接。
class InitialAppSettings {
  const InitialAppSettings({required this.themeMode, required this.locale});

  final ThemeMode themeMode;
  final Locale? locale;
}

/// 读取启动设置，读取失败时回退默认中文。
///
/// 异常策略：应用启动不能因为设置库损坏而中断；这里显式关闭临时数据库，
/// 避免启动阶段为了读取偏好留下额外连接。
Future<InitialAppSettings> loadInitialAppSettings() async {
  final database = AppDatabase();
  try {
    final repository = AppSettingsRepository(database: database);
    final mode = await repository.getThemeMode();
    final language = await repository.getLanguage();
    return InitialAppSettings(
      themeMode: themeModeFromSetting(mode),
      locale: localeFromSettingOrDevice(
        language,
        ui.PlatformDispatcher.instance.locale,
      ),
    );
  } catch (_) {
    return const InitialAppSettings(
      themeMode: ThemeMode.system,
      locale: defaultAppLocale,
    );
  } finally {
    await database.close();
  }
}

/// 兼容旧测试和单项调用的主题读取入口。
///
/// 设计意图：保留轻量公开函数，避免调用方只关心主题时必须理解完整设置对象。
Future<ThemeMode> loadInitialThemeMode() async {
  final settings = await loadInitialAppSettings();
  return settings.themeMode;
}

/// 应用根组件，集中配置路由和全局 GetX 容器。
///
/// 设计意图：让测试和入口函数复用同一个根组件，避免测试直接依赖
/// `runApp` 的副作用；全局依赖通过 InitialBinding 延迟注入，避免页面层
/// 直接创建数据库、平台通道等基础设施。
class ImageToolsApp extends StatelessWidget {
  const ImageToolsApp({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialLocale,
  });

  final ThemeMode initialThemeMode;
  final Locale? initialLocale;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Image Toolkit',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: resolveSupportedLocale(initialLocale ?? Get.deviceLocale),
      fallbackLocale: defaultAppLocale,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: initialThemeMode,
      initialBinding: InitialBinding(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: supportedAppLocales,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialSettings = await loadInitialAppSettings();
  runApp(
    ImageToolsApp(
      initialThemeMode: initialSettings.themeMode,
      initialLocale: initialSettings.locale,
    ),
  );
}
