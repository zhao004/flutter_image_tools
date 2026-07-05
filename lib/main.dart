import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'app/routes/app_pages.dart';

/// 应用根组件，集中配置路由和全局 GetX 容器。
///
/// 设计意图：让测试和入口函数复用同一个根组件，避免测试直接依赖
/// `runApp` 的副作用；当前没有异步初始化，因此构造函数保持无状态。
class ImageToolsApp extends StatelessWidget {
  const ImageToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Application',
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}

void main() {
  runApp(const ImageToolsApp());
}
