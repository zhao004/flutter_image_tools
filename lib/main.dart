import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/database/database.dart';
import 'app/repositories/app_settings_repository.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_mode_parser.dart';

/// 读取启动主题模式，读取失败时回退跟随系统。
///
/// 异常策略：应用启动不能因为设置库损坏而中断；这里显式关闭临时数据库，
/// 避免启动阶段为了读取主题留下额外连接。
Future<ThemeMode> loadInitialThemeMode() async {
  final database = AppDatabase();
  try {
    final repository = AppSettingsRepository(database: database);
    final mode = await repository.getThemeMode();
    return themeModeFromSetting(mode);
  } catch (_) {
    return ThemeMode.system;
  } finally {
    await database.close();
  }
}

/// 应用根组件，集中配置路由和全局 GetX 容器。
///
/// 设计意图：让测试和入口函数复用同一个根组件，避免测试直接依赖
/// `runApp` 的副作用；全局依赖通过 InitialBinding 延迟注入，避免页面层
/// 直接创建数据库、平台通道等基础设施。
class ImageToolsApp extends StatelessWidget {
  const ImageToolsApp({super.key, this.initialThemeMode = ThemeMode.system});

  final ThemeMode initialThemeMode;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Image Toolkit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: initialThemeMode,
      initialBinding: InitialBinding(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialThemeMode = await loadInitialThemeMode();
  runApp(ImageToolsApp(initialThemeMode: initialThemeMode));
}
