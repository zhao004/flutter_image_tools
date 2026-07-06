import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/pages/history/history_controller.dart';
import 'package:flutter_image_tools/app/pages/history/history_view.dart';
import 'package:flutter_image_tools/app/repositories/operation_history_repository.dart';
import 'package:flutter_image_tools/app/theme/app_translations.dart';
import 'package:flutter_image_tools/app/theme/app_theme.dart';
import 'package:flutter_image_tools/main.dart';

void main() {
  testWidgets('显示首页内容', (WidgetTester tester) async {
    // 通过根组件启动应用，覆盖路由绑定和默认页面渲染路径。
    await tester.pumpWidget(
      const ImageToolsApp(initialLocale: Locale('zh', 'CN')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Image Toolkit'), findsOneWidget);
    expect(find.text('本地离线图片工具'), findsOneWidget);
    expect(find.text('图片压缩'), findsWidgets);
  });

  testWidgets('显示英文首页内容', (WidgetTester tester) async {
    // 使用固定英文 Locale 验证首页翻译键已接入，不依赖测试设备语言。
    await tester.pumpWidget(const ImageToolsApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Image Toolkit'), findsOneWidget);
    expect(find.text('Offline Local Image Toolkit'), findsOneWidget);
    expect(find.text('Image Compression'), findsWidgets);
  });

  testWidgets('显示英文历史记录页面', (WidgetTester tester) async {
    // 使用内存数据库直接渲染历史页，避免全局路由动画影响空状态断言。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = OperationHistoryRepository(database: database);
    Get.put(HistoryController(repository: repository));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const HistoryView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('History'), findsOneWidget);
    expect(find.text('No processing records'), findsOneWidget);
    expect(find.text('Search feature, path, or parameters'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);

    await database.close();
    Get.reset();
  });
}
