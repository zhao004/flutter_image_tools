import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

/// 应用根组件，集中配置路由和全局 GetX 容器。
///
/// 设计意图：让测试和入口函数复用同一个根组件，避免测试直接依赖
/// `runApp` 的副作用；全局依赖通过 InitialBinding 延迟注入，避免页面层
/// 直接创建数据库、平台通道等基础设施。
class ImageToolsApp extends StatelessWidget {
  const ImageToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Image Toolkit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialBinding: InitialBinding(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}

void main() {
  runApp(const ImageToolsApp());
}
