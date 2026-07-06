import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/core/models/cache_summary.dart';
import 'package:flutter_image_tools/app/pages/base64/base64_controller.dart';
import 'package:flutter_image_tools/app/pages/base64/base64_view.dart';
import 'package:flutter_image_tools/app/pages/cache/cache_controller.dart';
import 'package:flutter_image_tools/app/pages/cache/cache_view.dart';
import 'package:flutter_image_tools/app/pages/color_picker/color_picker_controller.dart';
import 'package:flutter_image_tools/app/pages/color_picker/color_picker_view.dart';
import 'package:flutter_image_tools/app/pages/favorites/favorites_controller.dart';
import 'package:flutter_image_tools/app/pages/favorites/favorites_view.dart';
import 'package:flutter_image_tools/app/pages/filter/filter_controller.dart';
import 'package:flutter_image_tools/app/pages/filter/filter_view.dart'
    as filter_page;
import 'package:flutter_image_tools/app/pages/grid/grid_controller.dart';
import 'package:flutter_image_tools/app/pages/grid/grid_view.dart' as grid_page;
import 'package:flutter_image_tools/app/pages/history/history_controller.dart';
import 'package:flutter_image_tools/app/pages/history/history_view.dart';
import 'package:flutter_image_tools/app/pages/logs/logs_controller.dart';
import 'package:flutter_image_tools/app/pages/logs/logs_view.dart';
import 'package:flutter_image_tools/app/pages/qrcode/qrcode_controller.dart';
import 'package:flutter_image_tools/app/pages/qrcode/qrcode_view.dart';
import 'package:flutter_image_tools/app/repositories/cache_repository.dart';
import 'package:flutter_image_tools/app/repositories/favorite_templates_repository.dart';
import 'package:flutter_image_tools/app/repositories/operation_history_repository.dart';
import 'package:flutter_image_tools/app/repositories/operation_logs_repository.dart';
import 'package:flutter_image_tools/app/repositories/recent_files_repository.dart';
import 'package:flutter_image_tools/app/services/local_image_channel.dart';
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

  testWidgets('显示英文日志管理页面', (WidgetTester tester) async {
    // 使用内存数据库直接渲染日志页，验证空状态和筛选控件翻译。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = OperationLogsRepository(database: database);
    Get.put(LogsController(repository: repository));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const LogsView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Log Management'), findsOneWidget);
    expect(find.text('No operation logs'), findsOneWidget);
    expect(
      find.text('Search feature, path, parameters, or errors'),
      findsOneWidget,
    );
    expect(find.text('All'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文收藏模板页面', (WidgetTester tester) async {
    // 使用内存数据库直接渲染收藏页，验证表单、空状态和筛选文案翻译。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = FavoriteTemplatesRepository(database: database);
    Get.put(FavoritesController(repository: repository));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const FavoritesView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Favorite Templates'), findsOneWidget);
    expect(find.text('New Template'), findsOneWidget);
    expect(find.text('Image Compression'), findsOneWidget);
    expect(find.text('Template Name'), findsOneWidget);
    expect(find.text('Parameters JSON'), findsOneWidget);
    expect(
      find.text('Search feature, template name, or parameters'),
      findsOneWidget,
    );
    expect(find.text('No favorite templates'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文缓存管理页面', (WidgetTester tester) async {
    // 直接预置缓存统计结果，避免 Widget 测试依赖平台临时目录通道。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = CacheRepository(database: database);
    final controller = CacheController(cacheRepository: repository);
    controller.summary.value = const CacheSummary(
      cacheDirectoryPath: '/tmp/image_toolkit',
      fileCount: 2,
      recordCount: 1,
      totalSizeBytes: 1536,
    );
    Get.put(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const CacheView(),
      ),
    );
    await tester.pump();

    expect(find.text('Cache Management'), findsOneWidget);
    expect(find.text('Cache Summary'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('2 files'), findsOneWidget);
    expect(find.text('Cache Size'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('1 records'), findsOneWidget);
    expect(find.text('Clear Cache'), findsWidgets);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文 Base64 页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证静态文案国际化，不触发平台图片选择通道。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      Base64Controller(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const Base64View(),
      ),
    );
    await tester.pump();

    expect(find.text('Base64'), findsOneWidget);
    expect(find.text('Image to Base64'), findsOneWidget);
    expect(
      find.text(
        'Select a local image to generate Base64 text. Max 12 MB per file.',
      ),
      findsOneWidget,
    );
    expect(find.text('Select Image'), findsOneWidget);
    expect(find.text('Generate Text'), findsOneWidget);
    expect(find.text('Base64 to Image'), findsOneWidget);
    expect(
      find.text('Paste Base64 text or data:image/png;base64,...'),
      findsOneWidget,
    );
    expect(find.text('Restore Image'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文二维码页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证生成和识别区域文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      QrcodeController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const QrcodeView(),
      ),
    );
    await tester.pump();

    expect(find.text('QR Code'), findsOneWidget);
    expect(find.text('Generate QR Code / Barcode'), findsOneWidget);
    expect(find.text('Enter text, a link, or a short note'), findsOneWidget);
    expect(find.text('Generate QR Code'), findsOneWidget);
    expect(find.text('Generate Barcode'), findsOneWidget);
    expect(find.text('Scan QR Code / Barcode'), findsOneWidget);
    expect(
      find.text(
        'Select an image containing a QR code or barcode. Scanning stays fully local.',
      ),
      findsOneWidget,
    );
    expect(find.text('Select and Scan'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文颜色提取页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证选图、预览和空状态文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      ColorPickerController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const ColorPickerView(),
      ),
    );
    await tester.pump();

    expect(find.text('Color Picker'), findsOneWidget);
    expect(find.text('Select Image'), findsWidgets);
    expect(
      find.text('Select an image, then tap the preview area to pick a color.'),
      findsOneWidget,
    );
    expect(find.text('Tap to Pick Color'), findsOneWidget);
    expect(
      find.text('The preview appears here after an image loads.'),
      findsOneWidget,
    );

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文九宫格切图页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证选图、网格和操作按钮文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      GridController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const grid_page.GridView(),
      ),
    );
    await tester.pump();

    expect(find.text('Grid Split'), findsOneWidget);
    expect(find.text('Select Image'), findsWidgets);
    expect(
      find.text(
        'Select a JPG, PNG, WebP, or BMP image to generate grid slices.',
      ),
      findsOneWidget,
    );
    expect(find.text('Grid Size'), findsOneWidget);
    expect(find.text('3 × 3'), findsOneWidget);
    expect(find.text('Generate Slices'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片滤镜页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证选图、滤镜类型和操作按钮文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      FilterController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const filter_page.FilterView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Filters'), findsOneWidget);
    expect(find.text('Select Image'), findsWidgets);
    expect(
      find.text(
        'Select a JPG, PNG, WebP, or BMP image to apply a local filter.',
      ),
      findsOneWidget,
    );
    expect(find.text('Filter Type'), findsOneWidget);
    expect(find.text('Grayscale'), findsOneWidget);
    expect(find.text('Sepia'), findsOneWidget);
    expect(find.text('Apply Filter'), findsOneWidget);

    await database.close();
    Get.reset();
  });
}
