import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flex_color_picker/flex_color_picker.dart' as flex_color_picker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_image_tools/app/models/cache_summary.dart';
import 'package:flutter_image_tools/app/models/local_image_file.dart';
import 'package:flutter_image_tools/app/pages/annotation/annotation_controller.dart';
import 'package:flutter_image_tools/app/pages/annotation/annotation_view.dart';
import 'package:flutter_image_tools/app/pages/base64/base64_controller.dart';
import 'package:flutter_image_tools/app/pages/base64/base64_view.dart';
import 'package:flutter_image_tools/app/pages/cache/cache_controller.dart';
import 'package:flutter_image_tools/app/pages/cache/cache_view.dart';
import 'package:flutter_image_tools/app/pages/color_picker/color_picker_controller.dart';
import 'package:flutter_image_tools/app/pages/color_picker/color_picker_view.dart';
import 'package:flutter_image_tools/app/pages/compress/compress_controller.dart';
import 'package:flutter_image_tools/app/pages/compress/compress_view.dart';
import 'package:flutter_image_tools/app/pages/convert/convert_controller.dart';
import 'package:flutter_image_tools/app/pages/convert/convert_view.dart';
import 'package:flutter_image_tools/app/pages/crop/crop_controller.dart';
import 'package:flutter_image_tools/app/pages/crop/crop_view.dart';
import 'package:flutter_image_tools/app/pages/exif/exif_controller.dart';
import 'package:flutter_image_tools/app/pages/exif/exif_view.dart';
import 'package:flutter_image_tools/app/pages/favorites/favorites_controller.dart';
import 'package:flutter_image_tools/app/pages/favorites/favorites_view.dart';
import 'package:flutter_image_tools/app/pages/flip/flip_controller.dart';
import 'package:flutter_image_tools/app/pages/flip/flip_view.dart';
import 'package:flutter_image_tools/app/pages/filter/filter_controller.dart';
import 'package:flutter_image_tools/app/pages/filter/filter_view.dart'
    as filter_page;
import 'package:flutter_image_tools/app/pages/gif/gif_controller.dart';
import 'package:flutter_image_tools/app/pages/gif/gif_view.dart';
import 'package:flutter_image_tools/app/pages/grid/grid_controller.dart';
import 'package:flutter_image_tools/app/pages/grid/grid_view.dart' as grid_page;
import 'package:flutter_image_tools/app/pages/history/history_controller.dart';
import 'package:flutter_image_tools/app/pages/history/history_view.dart';
import 'package:flutter_image_tools/app/pages/image_watermark/image_watermark_controller.dart';
import 'package:flutter_image_tools/app/pages/image_watermark/image_watermark_view.dart';
import 'package:flutter_image_tools/app/pages/logs/logs_controller.dart';
import 'package:flutter_image_tools/app/pages/logs/logs_view.dart';
import 'package:flutter_image_tools/app/pages/merge/merge_controller.dart';
import 'package:flutter_image_tools/app/pages/merge/merge_view.dart';
import 'package:flutter_image_tools/app/pages/pdf/pdf_controller.dart';
import 'package:flutter_image_tools/app/pages/pdf/pdf_view.dart';
import 'package:flutter_image_tools/app/pages/qrcode/qrcode_controller.dart';
import 'package:flutter_image_tools/app/pages/qrcode/qrcode_view.dart';
import 'package:flutter_image_tools/app/pages/rotate/rotate_controller.dart';
import 'package:flutter_image_tools/app/pages/rotate/rotate_view.dart';
import 'package:flutter_image_tools/app/pages/resize/resize_controller.dart';
import 'package:flutter_image_tools/app/pages/resize/resize_view.dart';
import 'package:flutter_image_tools/app/pages/settings/settings_controller.dart';
import 'package:flutter_image_tools/app/pages/settings/settings_view.dart';
import 'package:flutter_image_tools/app/pages/watermark/watermark_controller.dart';
import 'package:flutter_image_tools/app/pages/watermark/watermark_view.dart';
import 'package:flutter_image_tools/app/repositories/app_settings_repository.dart';
import 'package:flutter_image_tools/app/repositories/cache_repository.dart';
import 'package:flutter_image_tools/app/repositories/favorite_templates_repository.dart';
import 'package:flutter_image_tools/app/repositories/operation_history_repository.dart';
import 'package:flutter_image_tools/app/repositories/operation_logs_repository.dart';
import 'package:flutter_image_tools/app/repositories/recent_files_repository.dart';
import 'package:flutter_image_tools/app/services/local_image_channel.dart';
import 'package:flutter_image_tools/app/theme/app_translations.dart';
import 'package:flutter_image_tools/app/theme/app_theme.dart';
import 'package:flutter_image_tools/app/widgets/image_editor_scaffold.dart';
import 'package:flutter_image_tools/main.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets('显示首页内容', (WidgetTester tester) async {
    // 通过根组件启动应用，覆盖路由绑定和默认页面渲染路径。
    await tester.pumpWidget(
      const ImageToolsApp(initialLocale: Locale('zh', 'CN')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ImageToolKit'), findsOneWidget);
    expect(find.text('收藏工具'), findsOneWidget);
    expect(find.text('最近使用'), findsNothing);
    expect(find.text('选择图片后会显示在这里'), findsNothing);
    expect(find.text('设置'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await _closeRegisteredAppDatabase();
  });

  testWidgets('显示英文首页内容', (WidgetTester tester) async {
    // 使用固定英文 Locale 验证首页翻译键已接入，不依赖测试设备语言。
    await tester.pumpWidget(const ImageToolsApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('ImageToolKit'), findsOneWidget);
    expect(find.text('Favorite Tools'), findsOneWidget);
    expect(find.text('Recent Tools'), findsNothing);
    expect(find.text('Selected images will appear here'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await _closeRegisteredAppDatabase();
  });

  testWidgets('设置页加载后显示已保存的功能设置', (WidgetTester tester) async {
    // 复现设置页首次渲染默认值、随后异步加载本地设置的场景。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = _DelayedSettingsRepository(
      database: database,
      delay: const Duration(milliseconds: 50),
    );
    await repository.setDefaultSaveRule('feature_folder');
    await repository.setDefaultExportFormat('webp');
    await repository.setThemeMode('dark');
    await repository.setLanguage('en');
    Get.put(SettingsController(settingsRepository: repository));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('zh', 'CN'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const SettingsView(),
      ),
    );
    await tester.pump();
    expect(find.text('时间戳'), findsOneWidget);
    expect(find.text('JPG'), findsOneWidget);
    expect(find.text('系统'), findsNWidgets(2));

    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('功能目录'), findsOneWidget);
    expect(find.text('WebP'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('设置页切换功能设置后写入本地仓库', (WidgetTester tester) async {
    // 覆盖用户点击下拉选项后的保存路径，避免界面变化但本地设置未落库。
    final database = AppDatabase(NativeDatabase.memory());
    final repository = AppSettingsRepository(database: database);
    Get.put(SettingsController(settingsRepository: repository));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('zh', 'CN'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const SettingsView(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('时间戳'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('功能目录').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('JPG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WebP').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('系统').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('语言'), 240);
    await tester.tap(find.text('系统').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(await repository.getDefaultSaveRule(), 'feature_folder');
    expect(await repository.getDefaultExportFormat(), 'webp');
    expect(await repository.getThemeMode(), 'dark');
    expect(await repository.getLanguage(), 'en');

    await database.close();
    Get.reset();
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
    expect(find.text('Select Image'), findsWidgets);
    expect(find.text('Generate Text'), findsOneWidget);
    expect(find.text('Base64 to Image'), findsOneWidget);
    expect(
      find.text('Paste Base64 text or data:image/png;base64,...'),
      findsOneWidget,
    );
    expect(find.text('Save to Gallery'), findsOneWidget);

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

  testWidgets('统一编辑器选图后显示沉浸式工作台', (WidgetTester tester) async {
    // 验证顶部主操作、深色画布、状态浮层和底部工具区，避免单测依赖真实图片解码。
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: ImageEditorScaffold(
          title: 'Grid Split',
          selectedImage: const LocalImageFile(
            path: 'preview.png',
            name: 'preview.png',
            sizeBytes: 1024,
            mimeType: 'image/png',
            width: 800,
            height: 600,
          ),
          isBusy: false,
          emptyIcon: Icons.grid_on_outlined,
          emptyTitle: 'Select Image',
          emptyMessage: 'Select an image first.',
          pickLabel: 'Select One',
          repickLabel: 'Select Again',
          exportLabel: 'Save to Gallery',
          exportIcon: Icons.ios_share_outlined,
          onPickImage: () {},
          onExport: () {},
          previewBuilder: (context, image) => const SizedBox(
            key: ValueKey('editor-canvas'),
            width: 240,
            height: 160,
            child: ColoredBox(color: Colors.black12),
          ),
          bottomToolbar: const Text('Bottom Toolbar'),
          resultSummary: const Text('Result Summary'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Grid Split'), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
    expect(find.text('Save to Gallery'), findsNothing);
    expect(find.byKey(const ValueKey('editor-export-action')), findsOneWidget);
    final exportButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('editor-export-action')),
    );
    expect(exportButton.onPressed, isNotNull);
    expect(exportButton.tooltip, 'Save to Gallery');
    expect(find.byTooltip('Save to Gallery'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-canvas-surface')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editor-image-info-overlay')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('editor-result-overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-canvas')), findsOneWidget);
    expect(find.text('preview.png'), findsOneWidget);
    expect(find.text('Bottom Toolbar'), findsOneWidget);
    expect(find.text('Result Summary'), findsOneWidget);
  });

  testWidgets('统一编辑器窄屏图标导出按钮不溢出', (WidgetTester tester) async {
    // 窄屏继续保留纯图标主操作和 Tooltip，避免标题与辅助动作挤压。
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: ImageEditorScaffold(
          title: 'Image Compression',
          selectedImage: const LocalImageFile(
            path: 'preview.png',
            name: 'preview.png',
            sizeBytes: 1024,
            mimeType: 'image/png',
            width: 800,
            height: 600,
          ),
          isBusy: false,
          emptyIcon: Icons.compress,
          emptyTitle: 'Select Image',
          emptyMessage: 'Select an image first.',
          pickLabel: 'Select One',
          repickLabel: 'Select Again',
          exportLabel: 'Save to Gallery',
          exportIcon: Icons.save_outlined,
          onPickImage: () {},
          onExport: () {},
          previewBuilder: (context, image) =>
              const SizedBox(width: 240, height: 160),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('editor-export-action')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('editor-export-action')),
          )
          .tooltip,
      'Save to Gallery',
    );
    expect(find.text('Save to Gallery'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('图片预览失败时显示错误占位', (WidgetTester tester) async {
    // 无效文件路径必须落到可理解的占位状态，而不是向测试或页面抛出构建异常。
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: EditorImagePreview(
              image: LocalImageFile(
                path: 'missing-image.png',
                name: 'missing-image.png',
                sizeBytes: 1024,
                mimeType: 'image/png',
                width: 800,
                height: 600,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Image failed to load'), findsOneWidget);
    expect(find.text('missing-image.png'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('小缩略图坏图占位仅显示图标', (WidgetTester tester) async {
    // 缩略图空间不足时隐藏长文本，通过 Tooltip 保留错误详情，避免产生布局溢出。
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 64,
              child: EditorImageLoadError(imageName: 'missing-thumb.png'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('Image failed to load'), findsNothing);
    expect(find.text('missing-thumb.png'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击已选一级导航可收起并切换属性设置面板', (WidgetTester tester) async {
    // 同一导航负责折叠/恢复当前属性面板，切换到其他导航时立即展开新面板。
    var activeCategoryId = 'draw';
    bool isPrimaryToolSelected(String id) {
      // 只校验选中标记，避免测试与合并后的语义标签和动作细节强绑定。
      return tester
              .getSemantics(find.byKey(ValueKey('editor-primary-tool-$id')))
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (context, setState) {
                return EditorDynamicToolPanel(
                  categories: const [
                    ToolCategory(
                      id: 'draw',
                      name: 'Draw',
                      icon: Icons.draw_outlined,
                    ),
                    ToolCategory(
                      id: 'erase',
                      name: 'Erase',
                      icon: Icons.cleaning_services_outlined,
                    ),
                  ],
                  activeCategoryId: activeCategoryId,
                  onCategorySelected: (category) {
                    setState(() => activeCategoryId = category.id);
                  },
                  activePanel: Text(
                    activeCategoryId == 'draw'
                        ? 'Draw Settings'
                        : 'Erase Settings',
                  ),
                  showPanelHeader: false,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Draw Settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editor-tool-parameter-surface')),
      findsOneWidget,
    );
    expect(isPrimaryToolSelected('draw'), isTrue);

    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();

    expect(find.text('Draw Settings'), findsNothing);
    expect(
      find.byKey(const ValueKey('editor-tool-parameter-surface')),
      findsNothing,
    );
    expect(isPrimaryToolSelected('draw'), isFalse);

    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    expect(find.text('Erase Settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editor-tool-parameter-surface')),
      findsOneWidget,
    );
    expect(isPrimaryToolSelected('erase'), isTrue);

    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    expect(find.text('Erase Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑堆叠参数面板位于一级工具栏上方', (WidgetTester tester) async {
    // 堆叠面板必须完整占用自身高度，并与固定一级工具栏保留间距。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: EditorDynamicToolPanel(
              categories: const [
                ToolCategory(
                  id: 'draw',
                  name: 'Draw',
                  icon: Icons.draw_outlined,
                  subItems: [
                    ToolSubItem(
                      id: 'brush',
                      name: 'Brush',
                      icon: Icons.brush_outlined,
                    ),
                  ],
                ),
              ],
              activeCategoryId: 'draw',
              activeSubItemId: 'brush',
              onCategorySelected: (_) {},
              onSubItemSelected: (_) {},
              activePanel: const Text('Brush Settings'),
              compactPanel: true,
              stackCompactPanel: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final parameterPanelRect = tester.getRect(
      find.byKey(const ValueKey('editor-compact-tool-panel')),
    );
    final primaryToolbarRect = tester.getRect(
      find.byKey(const ValueKey('editor-primary-tool-tabs')),
    );
    expect(
      parameterPanelRect.bottom,
      lessThanOrEqualTo(primaryToolbarRect.top),
    );
    expect(parameterPanelRect.overlaps(primaryToolbarRect), isFalse);
    expect(find.text('Brush Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('短横屏编辑器保留可操作画布空间', (WidgetTester tester) async {
    // 参数面板按可用高度收缩，避免短横屏下工具区吞没整个图片画布。
    tester.view.physicalSize = const Size(720, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: ImageEditorScaffold(
          title: 'Landscape Editor',
          selectedImage: const LocalImageFile(
            path: 'preview.png',
            name: 'preview.png',
            sizeBytes: 1024,
            mimeType: 'image/png',
            width: 1200,
            height: 800,
          ),
          isBusy: false,
          emptyIcon: Icons.image_outlined,
          emptyTitle: 'Select Image',
          emptyMessage: 'Select an image first.',
          pickLabel: 'Select One',
          repickLabel: 'Select Again',
          exportLabel: 'Save',
          exportIcon: Icons.save_outlined,
          onPickImage: () {},
          onExport: () {},
          showPreviewInfo: false,
          expandPreviewToAvailableHeight: true,
          previewBuilder: (context, image) => const SizedBox.expand(
            key: ValueKey('landscape-editor-canvas'),
            child: ColoredBox(color: Colors.black12),
          ),
          bottomToolbar: EditorDynamicToolPanel(
            categories: const [
              ToolCategory(id: 'settings', name: 'Settings', icon: Icons.tune),
            ],
            activeCategoryId: 'settings',
            onCategorySelected: (_) {},
            activePanel: const SizedBox(
              height: 260,
              child: Text('Tall Settings Panel'),
            ),
            maxPanelHeight: 300,
          ),
        ),
      ),
    );
    await tester.pump();

    final canvasSize = tester.getSize(
      find.byKey(const ValueKey('landscape-editor-canvas')),
    );
    expect(canvasSize.height, greaterThanOrEqualTo(72));
    expect(
      find.byKey(const ValueKey('editor-tool-parameter-surface')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('统一编辑器底部导航占位顶起预览区', (WidgetTester tester) async {
    // 底部工具栏参与页面布局，避免工具入口悬浮遮挡图片预览。
    Widget buildEditor({required Widget? bottomToolbar}) {
      return GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: ImageEditorScaffold(
          title: 'Grid Split',
          selectedImage: const LocalImageFile(
            path: 'preview.png',
            name: 'preview.png',
            sizeBytes: 1024,
            mimeType: 'image/png',
            width: 800,
            height: 600,
          ),
          isBusy: false,
          emptyIcon: Icons.grid_on_outlined,
          emptyTitle: 'Select Image',
          emptyMessage: 'Select an image first.',
          pickLabel: 'Select One',
          repickLabel: 'Select Again',
          exportLabel: 'Save to Gallery',
          exportIcon: Icons.ios_share_outlined,
          onPickImage: () {},
          onExport: () {},
          showPreviewInfo: false,
          expandPreviewToAvailableHeight: true,
          previewBuilder: (context, image) => const SizedBox.expand(
            key: ValueKey('overlay-editor-canvas'),
            child: ColoredBox(color: Colors.black12),
          ),
          bottomToolbar: bottomToolbar,
        ),
      );
    }

    await tester.pumpWidget(buildEditor(bottomToolbar: null));
    await tester.pump();
    final initialSize = tester.getSize(
      find.byKey(const ValueKey('overlay-editor-canvas')),
    );

    await tester.pumpWidget(
      buildEditor(
        bottomToolbar: const SizedBox(
          key: ValueKey('overlay-property-panel'),
          height: 180,
          child: Text('Property Panel'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Property Panel'), findsOneWidget);
    final nextSize = tester.getSize(
      find.byKey(const ValueKey('overlay-editor-canvas')),
    );
    expect(nextSize.height, lessThan(initialSize.height));
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('overlay-property-panel')),
    );
    final canvasRect = tester.getRect(
      find.byKey(const ValueKey('overlay-editor-canvas')),
    );
    expect(panelRect.top, greaterThanOrEqualTo(canvasRect.bottom));
  });

  testWidgets('显示英文图片滤镜页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证统一编辑器选图空状态文案国际化。
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
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsWidgets);
    expect(find.byIcon(Icons.save_outlined), findsWidgets);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文 EXIF 管理页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证选图、信息区和操作按钮文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      ExifController(
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
        home: const ExifView(),
      ),
    );
    await tester.pump();

    expect(find.text('EXIF Manager'), findsOneWidget);
    expect(find.text('Select Image'), findsWidgets);
    expect(
      find.text(
        'Select a local image to read capture time, camera, GPS, and other EXIF information.',
      ),
      findsOneWidget,
    );
    expect(find.text('Read Again'), findsOneWidget);
    expect(find.text('Save to Gallery'), findsOneWidget);
    expect(find.text('EXIF Information'), findsOneWidget);
    expect(
      find.text('Readable EXIF fields appear after selecting an image.'),
      findsOneWidget,
    );

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片标注页面', (WidgetTester tester) async {
    // 先验证统一编辑器空状态，再注入图片进入工具标签和属性面板布局。
    final database = AppDatabase(NativeDatabase.memory());
    final controller = Get.put(
      AnnotationController(
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
        home: const AnnotationView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Editor'), findsOneWidget);
    expect(find.text('Select Image'), findsWidgets);
    expect(
      find.text(
        'Select one image to enter the editor, then use the tool tabs for text, shapes, arrows, mosaic, and brush.',
      ),
      findsOneWidget,
    );
    expect(find.text('Move'), findsNothing);

    controller.selectedImage.value = const LocalImageFile(
      path: 'annotation_preview.png',
      name: 'annotation_preview.png',
      sizeBytes: 1200,
      mimeType: 'image/png',
      width: 1200,
      height: 800,
    );
    await tester.pump();

    expect(find.text('Move'), findsNothing);
    expect(find.text('Annotate'), findsOneWidget);
    expect(find.text('Mosaic'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Brush'), findsNothing);
    expect(find.text('Rectangle'), findsNothing);
    expect(find.text('Circle'), findsNothing);
    expect(find.text('Arrow'), findsNothing);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    expect(find.text('Resize'), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('annotation_preview.png'), findsNothing);
    expect(find.textContaining('1200 × 800'), findsNothing);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('#E53935'), findsNothing);
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey('editor-bottom-toolbar-surface')),
    );
    final primaryTabsRect = tester.getRect(
      find.byKey(const ValueKey('editor-primary-tool-tabs')),
    );
    expect(primaryTabsRect.top - toolbarRect.top, lessThanOrEqualTo(12));
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    expect(find.text('Annotation Style'), findsNothing);
    expect(find.text('Edit Text'), findsNothing);
    expect(find.text('Text Content'), findsOneWidget);
    expect(find.text('Text Size: 32 px'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Monospace'), findsOneWidget);

    controller.textController.text = 'Updated text';
    controller.updateTextSize(48);
    controller.setTextFont(AnnotationTextFont.monospace);
    await tester.pump();

    expect(find.text('Annotation Style'), findsNothing);
    expect(find.text('Text Size: 48 px'), findsOneWidget);
    expect(controller.updateSelectedTextLayer(), isTrue);
    final updatedText = controller.selectedObject.value as TextDrawable;
    expect(updatedText.text, 'Updated text');
    expect(updatedText.style.fontSize, 48);
    expect(updatedText.style.fontFamily, 'monospace');
    expect(controller.selectTextObjectAt(updatedText.position), isTrue);

    if (find.byType(BottomSheet).evaluate().isNotEmpty) {
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
    }
    controller.deselectSelectedObject();
    await tester.pump();

    expect(find.text('Annotation Style'), findsNothing);
    controller.handleCanvasTap(updatedText.position);
    await tester.pump();

    expect(controller.selectedObject.value, isA<TextDrawable>());
    expect(find.text('Annotation Style'), findsNothing);
    expect(find.text('Edit Text'), findsNothing);
    expect(find.text('Text Size: 48 px'), findsOneWidget);
    expect(find.text('#E53935'), findsOneWidget);

    final painterBox =
        controller.painterController.painterKey.currentContext!
                .findRenderObject()
            as RenderBox;
    await tester.tapAt(painterBox.localToGlobal(updatedText.position));
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(controller.selectedObject.value, isA<TextDrawable>());
    expect(find.text('Annotation Style'), findsNothing);

    await tester.tapAt(painterBox.localToGlobal(const Offset(4, 4)));
    await tester.pumpAndSettle();

    expect(controller.selectedObject.value, isNull);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    controller.handleCanvasTap(updatedText.position);
    await tester.pump();
    expect(controller.selectedObject.value, isA<TextDrawable>());

    controller.addShapeLayer(EditableLayerType.rectangle);
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    controller.closePropertyPanel();
    await tester.pump();

    expect(find.text('Annotation Style'), findsNothing);
    final rectangle = controller.selectedObject.value!;
    controller.handleCanvasTap(rectangle.position);
    await tester.pump();

    expect(find.text('Annotation Style'), findsNothing);
    expect(find.text('#E53935'), findsOneWidget);
    expect(find.text('Stroke: 12 px'), findsOneWidget);

    await tester.tap(find.text('#E53935'));
    await tester.pumpAndSettle();

    expect(find.text('Color'), findsOneWidget);
    expect(find.byType(flex_color_picker.ColorPicker), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();

    controller.setColor(const Color(0xFF123456));
    await tester.pump();
    expect(controller.color.value, const Color(0xFF123456));
    expect(find.text('#123456'), findsOneWidget);

    controller.deselectSelectedObjectIfBlankTap(const Offset(0, 0));
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(find.text('Annotate'));
    await tester.pumpAndSettle();
    expect(find.text('Brush'), findsOneWidget);
    expect(find.text('Rectangle'), findsOneWidget);
    expect(find.text('Circle'), findsOneWidget);
    expect(find.text('Arrow'), findsOneWidget);

    await tester.tap(find.text('Brush'));
    await tester.pumpAndSettle();

    expect(find.text('Annotation Style'), findsNothing);
    expect(find.byTooltip('Close Property Panel'), findsOneWidget);
    expect(find.text('#123456'), findsOneWidget);
    expect(find.text('Stroke: 12 px'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Close Property Panel'));
    await tester.pumpAndSettle();

    expect(controller.mode.value, AnnotationMode.select);
    expect(find.text('Annotation Style'), findsNothing);
    expect(find.text('#123456'), findsNothing);
    expect(find.text('Stroke: 12 px'), findsNothing);

    await tester.tap(find.text('Mosaic'));
    await tester.pumpAndSettle();

    expect(find.text('Freehand'), findsWidgets);
    expect(find.text('Rectangle Mosaic'), findsWidgets);
    expect(find.text('Circle Mosaic'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Freehand'));
    await tester.pumpAndSettle();

    expect(find.text('Annotation Style'), findsNothing);
    expect(find.text('Freehand'), findsWidgets);
    expect(find.text('Rectangle Mosaic'), findsWidgets);
    expect(find.byTooltip('Close Property Panel'), findsOneWidget);
    expect(find.text('#123456'), findsOneWidget);
    expect(find.text('Stroke: 12 px'), findsOneWidget);

    controller.setMosaicDrawMode(MosaicDrawMode.rectangle);
    controller.addMosaicStroke(const [
      Offset(8, 8),
      Offset(80, 48),
    ], kind: MosaicStrokeKind.rectangle);
    await tester.pump();

    expect(controller.strokes.last.color, const Color(0xFF123456));
    expect(find.text('Rectangle Mosaic'), findsWidgets);
    expect(find.text('Stroke: 12 px'), findsNothing);

    controller.deselectSelectedObjectIfBlankTap(const Offset(1000, 1000));
    await tester.pump();

    expect(controller.selectedObject.value, isNull);
    expect(controller.selectedMosaicIndex.value, isNull);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    controller.selectShapeTool(EditableLayerType.arrow);
    await tester.pump();

    expect(find.byKey(const ValueKey('annotation-mosaic-layer')), findsWidgets);
    expect(find.text('Solid Arrow'), findsOneWidget);
    expect(find.text('Outline Arrow'), findsOneWidget);
    expect(find.text('Stroke: 12 px'), findsOneWidget);

    controller.clearEdits(showMessage: false);
    controller.setMode(AnnotationMode.filter);
    await tester.pump();

    expect(find.text('Filter Settings'), findsNothing);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Sepia'), findsOneWidget);
    expect(controller.hasEdits, isFalse);

    controller.setFilter(ImageFilterType.sepia);
    await tester.pump();

    expect(controller.hasEdits, isTrue);
    expect(
      find.byKey(const ValueKey('annotation-adjustment-preview')),
      findsOneWidget,
    );

    controller.setMode(AnnotationMode.rotate);
    await tester.pump();

    expect(find.text('Rotate Settings'), findsNothing);
    expect(find.text('Rotate Left 90°'), findsOneWidget);
    expect(find.text('Rotate Right 90°'), findsOneWidget);
    controller.rotateByQuarterTurn(90);
    expect(controller.rotationDegrees.value, 90);
    expect(
      controller.previewAspectRatioFor(controller.selectedImage.value!),
      closeTo(800 / 1200, 0.001),
    );

    controller.setMode(AnnotationMode.flip);
    await tester.pump();

    expect(find.text('Flip Direction'), findsNothing);
    expect(find.text('Horizontal Flip'), findsOneWidget);
    expect(find.text('Vertical Flip'), findsOneWidget);
    controller.setFlipHorizontal(true);
    expect(controller.hasImageAdjustments, isTrue);

    controller.setMode(AnnotationMode.resize);
    await tester.pump();

    expect(find.text('Target Size'), findsNothing);
    expect(find.text('1200 × 800 px'), findsOneWidget);
    await tester.tap(find.text('1200 × 800 px'));
    await tester.pumpAndSettle();

    expect(find.text('Width'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Keep Aspect Ratio'), findsOneWidget);
    controller.updateResizePercent(50);
    expect(controller.resizeWidthController.text, '600');
    expect(controller.resizeHeightController.text, '400');
    expect(
      controller.previewSizeFor(controller.selectedImage.value!),
      const Size(600, 400),
    );
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    controller.updateResizePercent(100);
    controller.setMode(AnnotationMode.crop);
    await tester.pump();

    expect(find.text('Crop Ratio'), findsNothing);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Square'), findsOneWidget);
    controller.setCropPreset(AnnotationCropPreset.square);
    expect(controller.cropPreset.value, AnnotationCropPreset.square);
    expect(
      controller.previewAspectRatioFor(controller.selectedImage.value!),
      closeTo(1, 0.001),
    );

    controller.setMode(AnnotationMode.brush);
    await tester.pump();

    expect(controller.hasImageAdjustments, isTrue);
    expect(
      find.byKey(const ValueKey('annotation-adjustment-preview')),
      findsOneWidget,
    );
    expect(find.byType(ColorFiltered), findsWidgets);
    expect(find.byType(RotatedBox), findsWidgets);
    expect(find.byType(Transform), findsWidgets);

    await database.close();
    Get.reset();
  });

  test('图片编辑处理链支持滤镜旋转翻转尺寸和裁剪', () {
    // 用纯 Dart 像素管线验证最终导出处理顺序，避免单测依赖相册权限。
    final source = img.Image(width: 4, height: 2);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, x * 40, y * 80, 20, 255);
      }
    }

    final result = LocalImageChannel().processEditedImage(
      image: source,
      filter: 'grayscale',
      rotationDegrees: 90,
      flipHorizontal: true,
      flipVertical: true,
      resizeWidth: 3,
      resizeHeight: 3,
      cropAspectRatio: 1,
    );

    expect(result.width, 3);
    expect(result.height, 3);
    final pixel = result.getPixel(1, 1);
    expect(pixel.r, equals(pixel.g));
    expect(pixel.g, equals(pixel.b));
  });

  test('箭头缩放与方向调整职责分离', () async {
    // 箭头端点仅沿当前方向投影调整长度；独立方向手柄负责旋转，避免一个手势同时改变方向和长度。
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AnnotationController(
      imageChannel: LocalImageChannel(),
      historyRepository: OperationHistoryRepository(database: database),
      recentFilesRepository: RecentFilesRepository(database: database),
    );
    controller.selectedImage.value = const LocalImageFile(
      path: 'annotation_preview.png',
      name: 'annotation_preview.png',
      sizeBytes: 1200,
      mimeType: 'image/png',
      width: 1200,
      height: 800,
    );
    controller.updateCanvasSize(const Size(300, 200));
    controller.addShapeLayer(EditableLayerType.arrow);

    final initial = controller.selectedObject.value as EditableArrowDrawable;
    expect(initial.rotationAngle, 0);

    controller.updateSelectedArrowScaleHandle(
      isHead: true,
      point: initial.position + const Offset(140, 80),
    );
    final scaled = controller.selectedObject.value as EditableArrowDrawable;

    expect(scaled.length, greaterThan(initial.length));
    expect(scaled.rotationAngle, initial.rotationAngle);

    controller.rotateSelectedArrowTo(scaled.position + const Offset(0, 120));
    final rotated = controller.selectedObject.value as EditableArrowDrawable;

    expect(rotated.length, scaled.length);
    expect(rotated.rotationAngle, closeTo(1.5707963267948966, 0.001));

    await database.close();
    Get.reset();
  });

  test('矩形和圆形支持四角拖动缩放', () async {
    // 四角控制点使用对角固定策略，矩形自由缩放，圆形保持正圆比例。
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AnnotationController(
      imageChannel: LocalImageChannel(),
      historyRepository: OperationHistoryRepository(database: database),
      recentFilesRepository: RecentFilesRepository(database: database),
    );
    controller.selectedImage.value = const LocalImageFile(
      path: 'annotation_preview.png',
      name: 'annotation_preview.png',
      sizeBytes: 1200,
      mimeType: 'image/png',
      width: 1200,
      height: 800,
    );
    controller.updateCanvasSize(const Size(300, 200));

    controller.addShapeLayer(EditableLayerType.rectangle);
    final rectangleGeometry = controller.selectedControlGeometry!;
    expect(rectangleGeometry.shapeScaleHandles, hasLength(4));
    final initialRectangle =
        controller.selectedObject.value as RectangleDrawable;
    final rectBottomRight = rectangleGeometry.shapeScaleHandles.singleWhere(
      (handle) => handle.corner == AnnotationShapeScaleCorner.bottomRight,
    );
    controller.resizeSelectedShapeFromCorner(
      corner: rectBottomRight.corner,
      point: rectBottomRight.center + const Offset(50, 30),
    );
    final resizedRectangle =
        controller.selectedObject.value as RectangleDrawable;
    expect(
      resizedRectangle.size.width,
      greaterThan(initialRectangle.size.width),
    );
    expect(
      resizedRectangle.size.height,
      greaterThan(initialRectangle.size.height),
    );

    controller.addTextLayer(text: '比例稳定');
    final stableText = controller.selectedObject.value as TextDrawable;

    controller.addShapeLayer(EditableLayerType.circle);
    final circleGeometry = controller.selectedControlGeometry!;
    expect(circleGeometry.shapeScaleHandles, hasLength(4));
    final initialCircle = controller.selectedObject.value as OvalDrawable;
    final circleBottomRight = circleGeometry.shapeScaleHandles.singleWhere(
      (handle) => handle.corner == AnnotationShapeScaleCorner.bottomRight,
    );
    controller.resizeSelectedShapeFromCorner(
      corner: circleBottomRight.corner,
      point: circleBottomRight.center + const Offset(44, 20),
    );
    final resizedCircle = controller.selectedObject.value as OvalDrawable;
    expect(resizedCircle.size.width, greaterThan(initialCircle.size.width));
    expect(resizedCircle.size.width, resizedCircle.size.height);

    controller.addMosaicStroke(const [
      Offset(20, 20),
      Offset(80, 60),
    ], kind: MosaicStrokeKind.rectangle);
    expect(controller.selectedMosaicIndex.value, 0);
    expect(controller.mosaicDrawMode.value, MosaicDrawMode.rectangle);
    final rectangleMosaicGeometry = controller.selectedControlGeometry!;
    expect(rectangleMosaicGeometry.shapeScaleHandles, hasLength(4));
    final initialRectangleMosaicPoints = List<Offset>.of(
      controller.strokes.first.points,
    );

    controller.moveSelectedMosaicBy(const Offset(10, 12));
    expect(
      controller.strokes.first.points.first,
      initialRectangleMosaicPoints.first + const Offset(10, 12),
    );
    final mosaicBottomRight = rectangleMosaicGeometry.shapeScaleHandles
        .singleWhere(
          (handle) => handle.corner == AnnotationShapeScaleCorner.bottomRight,
        );
    controller.resizeSelectedMosaicFromCorner(
      corner: mosaicBottomRight.corner,
      point: mosaicBottomRight.center + const Offset(40, 24),
    );
    final resizedRectangleMosaic = Rect.fromPoints(
      controller.strokes.first.points.first,
      controller.strokes.first.points.last,
    );
    expect(resizedRectangleMosaic.width, greaterThan(60));
    expect(resizedRectangleMosaic.height, greaterThan(40));
    final stableMosaicPoint = controller.strokes.first.points.first;

    controller.updateCanvasSize(const Size(300, 150));
    final compactText = controller.painterController.drawables
        .whereType<TextDrawable>()
        .singleWhere((drawable) => drawable.text == '比例稳定');
    expect(compactText.position.dx, closeTo(stableText.position.dx, 0.001));
    expect(compactText.position.dy, closeTo(stableText.position.dy, 0.001));
    expect(controller.strokes.first.points.first.dx, stableMosaicPoint.dx);
    expect(controller.strokes.first.points.first.dy, stableMosaicPoint.dy);

    controller.updateCanvasSize(const Size(300, 200));
    final restoredText = controller.painterController.drawables
        .whereType<TextDrawable>()
        .singleWhere((drawable) => drawable.text == '比例稳定');
    expect(restoredText.position.dx, closeTo(stableText.position.dx, 0.001));
    expect(restoredText.position.dy, closeTo(stableText.position.dy, 0.001));
    expect(
      controller.strokes.first.points.first.dx,
      closeTo(stableMosaicPoint.dx, 0.001),
    );
    expect(
      controller.strokes.first.points.first.dy,
      closeTo(stableMosaicPoint.dy, 0.001),
    );

    controller.addMosaicStroke(const [
      Offset(100, 40),
      Offset(140, 90),
    ], kind: MosaicStrokeKind.circle);
    expect(controller.selectedMosaicIndex.value, 1);
    expect(controller.mosaicDrawMode.value, MosaicDrawMode.circle);
    final circleMosaicGeometry = controller.selectedControlGeometry!;
    expect(circleMosaicGeometry.shapeScaleHandles, hasLength(4));
    final circleMosaicBottomRight = circleMosaicGeometry.shapeScaleHandles
        .singleWhere(
          (handle) => handle.corner == AnnotationShapeScaleCorner.bottomRight,
        );
    controller.resizeSelectedMosaicFromCorner(
      corner: circleMosaicBottomRight.corner,
      point: circleMosaicBottomRight.center + const Offset(30, 10),
    );
    final resizedCircleMosaic = Rect.fromPoints(
      controller.strokes[1].points.first,
      controller.strokes[1].points.last,
    );
    expect(resizedCircleMosaic.width, resizedCircleMosaic.height);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片翻转页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证统一编辑器选图空状态文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      FlipController(
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
        home: const FlipView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Flip'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(
      find.text('Select a JPG, PNG, WebP, or BMP image to flip locally.'),
      findsOneWidget,
    );
    expect(find.text('Select One'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片旋转页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证统一编辑器选图空状态文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      RotateController(
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
        home: const RotateView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Rotate'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(
      find.text('Select a JPG, PNG, WebP, or BMP image to rotate locally.'),
      findsOneWidget,
    );
    expect(find.text('Select One'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片压缩页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证选图、质量和操作按钮文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      CompressController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        settingsRepository: AppSettingsRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const CompressView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Compression'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(
      find.text('Select a JPG, PNG, or WebP image to compress locally.'),
      findsOneWidget,
    );
    expect(find.text('Select One'), findsOneWidget);
    expect(find.text('Select Batch'), findsNothing);
    expect(find.text('Compression Quality'), findsWidgets);
    expect(find.text('Current Quality: 80%'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-export-action')), findsOneWidget);
    expect(find.text('Save to Gallery'), findsNothing);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文格式转换页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证选图、格式和质量文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      ConvertController(
        imageChannel: LocalImageChannel(),
        historyRepository: OperationHistoryRepository(database: database),
        settingsRepository: AppSettingsRepository(database: database),
        recentFilesRepository: RecentFilesRepository(database: database),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const ConvertView(),
      ),
    );
    await tester.pump();

    expect(find.text('Format Convert'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(
      find.text('Select a JPG, PNG, WebP, or BMP image to convert locally.'),
      findsOneWidget,
    );
    expect(find.text('Select One'), findsOneWidget);
    expect(find.text('Select Batch'), findsNothing);
    expect(find.text('Export Format'), findsWidgets);
    expect(find.text('JPG'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('Export Quality: 95%'), findsOneWidget);
    expect(find.text('JPG and WebP use the export quality.'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-export-action')), findsOneWidget);
    expect(find.text('Save to Gallery'), findsNothing);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文尺寸调整页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证统一编辑器选图空状态文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      ResizeController(
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
        home: const ResizeView(),
      ),
    );
    await tester.pump();

    expect(find.text('Resize'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(
      find.text('Select a JPG, PNG, WebP, or BMP image to resize locally.'),
      findsOneWidget,
    );
    expect(find.text('Select One'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片裁剪页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证统一编辑器选图空状态文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      CropController(
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
        home: const CropView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Crop'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(
      find.text('Select a JPG, PNG, WebP, or BMP image for local cropping.'),
      findsOneWidget,
    );
    expect(find.text('Select One'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    await database.close();
    Get.reset();
  });

  test('裁剪框拖动更新位置并限制在图片范围内', () async {
    // 控制器使用归一化中心点记录拖动位置，边界钳制避免导出区域越界。
    final database = AppDatabase(NativeDatabase.memory());
    final controller = CropController(
      imageChannel: LocalImageChannel(),
      historyRepository: OperationHistoryRepository(database: database),
      recentFilesRepository: RecentFilesRepository(database: database),
    );
    const image = LocalImageFile(
      path: 'preview.png',
      name: 'preview.png',
      sizeBytes: 100,
      mimeType: 'image/png',
      width: 1600,
      height: 900,
    );

    final initialFrame = controller.frameRatiosForImage(image, 1);
    controller.updateCropFrame(
      centerXRatio: 0.9,
      centerYRatio: 0.9,
      frameWidthRatio: initialFrame.width,
      frameHeightRatio: initialFrame.height,
    );
    final movedFrame = controller.frameRatiosForImage(image, 1);

    expect(movedFrame.left, greaterThan(initialFrame.left));
    expect(movedFrame.top, equals(0));
    expect(movedFrame.left + movedFrame.width, lessThanOrEqualTo(1));
    expect(movedFrame.top + movedFrame.height, lessThanOrEqualTo(1));

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片拼接页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证选图、布局和首屏参数文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    void expectReadableScrollablePreview({
      required String viewportKey,
      required bool shouldOverflowHorizontally,
      required bool shouldOverflowVertically,
    }) {
      // 用几何断言覆盖适度缩放策略：预览保持可读尺寸，超出视口时交给滚动查看。
      final viewport = tester.getRect(find.byKey(ValueKey(viewportKey)));
      final firstTile = tester.getRect(
        find.byKey(const ValueKey('merge-preview-tile-first.png')),
      );
      final secondTile = tester.getRect(
        find.byKey(const ValueKey('merge-preview-tile-second.png')),
      );
      const tolerance = 1.0;
      final content = firstTile.expandToInclude(secondTile);

      if (shouldOverflowHorizontally) {
        expect(content.width, greaterThan(viewport.width + tolerance));
      } else {
        expect(content.width, lessThanOrEqualTo(viewport.width + tolerance));
      }
      if (shouldOverflowVertically) {
        expect(content.height, greaterThan(viewport.height + tolerance));
      } else {
        expect(content.height, lessThanOrEqualTo(viewport.height + tolerance));
      }

      expect(firstTile.width, greaterThan(tolerance));
      expect(firstTile.height, greaterThan(tolerance));
      expect(secondTile.width, greaterThan(tolerance));
      expect(secondTile.height, greaterThan(tolerance));
    }

    void expectVisiblePreviewTiles({
      required String viewportKey,
      required List<String> visibleTileKeys,
      required String overflowTileKey,
      required bool horizontal,
    }) {
      // 通过首屏几何位置验证多图默认缩放数量，剩余图片仍在滚动画布中可访问。
      final viewport = tester.getRect(find.byKey(ValueKey(viewportKey)));
      const tolerance = 1.0;

      for (final key in visibleTileKeys) {
        final tile = tester.getRect(find.byKey(ValueKey(key)));
        if (horizontal) {
          expect(tile.left, greaterThanOrEqualTo(viewport.left - tolerance));
          expect(tile.right, lessThanOrEqualTo(viewport.right + tolerance));
        } else {
          expect(tile.top, greaterThanOrEqualTo(viewport.top - tolerance));
          expect(tile.bottom, lessThanOrEqualTo(viewport.bottom + tolerance));
        }
      }

      final overflowTile = tester.getRect(
        find.byKey(ValueKey(overflowTileKey)),
      );
      if (horizontal) {
        expect(
          overflowTile.left,
          greaterThanOrEqualTo(viewport.right - tolerance),
        );
      } else {
        expect(
          overflowTile.top,
          greaterThanOrEqualTo(viewport.bottom - tolerance),
        );
      }
    }

    Get.put(
      MergeController(
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
        home: const MergeView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Merge'), findsOneWidget);
    expect(find.text('Select Images'), findsOneWidget);
    expect(
      find.text(
        'Select 2 to 20 JPG, PNG, WebP, or BMP images to merge locally.',
      ),
      findsOneWidget,
    );
    expect(find.text('Select Batch'), findsOneWidget);
    expect(find.text('Merge Layout'), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);

    Get.find<MergeController>().selectedImages.assignAll(const [
      LocalImageFile(
        path: 'first.png',
        name: 'first.png',
        sizeBytes: 1200,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
      LocalImageFile(
        path: 'second.png',
        name: 'second.png',
        sizeBytes: 2400,
        mimeType: 'image/png',
        width: 400,
        height: 1200,
      ),
    ]);
    await tester.pump();

    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Border'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('Order'), findsOneWidget);
    expect(find.text('Horizontal'), findsOneWidget);
    expect(find.text('Vertical'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merge-preview-horizontal-scroll')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merge-preview-vertical-scroll')),
      findsNothing,
    );
    expect(find.text('Grid'), findsNothing);
    expect(find.text('Long Image'), findsNothing);
    expect(find.text('Image Spacing: 8px'), findsOneWidget);
    expectReadableScrollablePreview(
      viewportKey: 'merge-preview-horizontal-scroll',
      shouldOverflowHorizontally: false,
      shouldOverflowVertically: true,
    );

    Get.find<MergeController>().selectedImages.assignAll(const [
      LocalImageFile(
        path: 'first.png',
        name: 'first.png',
        sizeBytes: 1200,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
      LocalImageFile(
        path: 'second.png',
        name: 'second.png',
        sizeBytes: 2400,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
      LocalImageFile(
        path: 'third.png',
        name: 'third.png',
        sizeBytes: 3600,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
    ]);
    await tester.pump();
    expectVisiblePreviewTiles(
      viewportKey: 'merge-preview-horizontal-scroll',
      visibleTileKeys: const [
        'merge-preview-tile-first.png',
        'merge-preview-tile-second.png',
      ],
      overflowTileKey: 'merge-preview-tile-third.png',
      horizontal: true,
    );

    Get.find<MergeController>().selectedImages.assignAll(const [
      LocalImageFile(
        path: 'first.png',
        name: 'first.png',
        sizeBytes: 1200,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
      LocalImageFile(
        path: 'second.png',
        name: 'second.png',
        sizeBytes: 2400,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
      LocalImageFile(
        path: 'third.png',
        name: 'third.png',
        sizeBytes: 3600,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
      LocalImageFile(
        path: 'fourth.png',
        name: 'fourth.png',
        sizeBytes: 4800,
        mimeType: 'image/png',
        width: 800,
        height: 600,
      ),
    ]);
    await tester.pump();
    expectVisiblePreviewTiles(
      viewportKey: 'merge-preview-horizontal-scroll',
      visibleTileKeys: const [
        'merge-preview-tile-first.png',
        'merge-preview-tile-second.png',
        'merge-preview-tile-third.png',
      ],
      overflowTileKey: 'merge-preview-tile-fourth.png',
      horizontal: true,
    );

    final spacingSlider = find.byType(Slider);
    expect(spacingSlider, findsOneWidget);
    expect(tester.getSize(spacingSlider).height, greaterThanOrEqualTo(48));

    await tester.drag(spacingSlider, const Offset(800, 0));
    await tester.pump();

    expect(Get.find<MergeController>().spacing.value, 100);
    expect(find.text('Image Spacing: 100px'), findsOneWidget);

    await tester.tap(find.text('Vertical'));
    await tester.pumpAndSettle();

    expect(Get.find<MergeController>().mode.value, MergeMode.vertical);
    expect(
      find.byKey(const ValueKey('merge-preview-horizontal-scroll')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('merge-preview-vertical-scroll')),
      findsOneWidget,
    );
    expectVisiblePreviewTiles(
      viewportKey: 'merge-preview-vertical-scroll',
      visibleTileKeys: const [
        'merge-preview-tile-first.png',
        'merge-preview-tile-second.png',
        'merge-preview-tile-third.png',
      ],
      overflowTileKey: 'merge-preview-tile-fourth.png',
      horizontal: false,
    );

    await tester.tap(find.text('Horizontal'));
    await tester.pumpAndSettle();

    expect(Get.find<MergeController>().mode.value, MergeMode.horizontal);
    expect(
      find.byKey(const ValueKey('merge-preview-horizontal-scroll')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merge-preview-vertical-scroll')),
      findsNothing,
    );
    expectVisiblePreviewTiles(
      viewportKey: 'merge-preview-horizontal-scroll',
      visibleTileKeys: const [
        'merge-preview-tile-first.png',
        'merge-preview-tile-second.png',
        'merge-preview-tile-third.png',
      ],
      overflowTileKey: 'merge-preview-tile-fourth.png',
      horizontal: true,
    );

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文文字水印页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，验证空状态和选图后的紧凑覆盖式配置栏。
    final database = AppDatabase(NativeDatabase.memory());
    final controller = WatermarkController(
      imageChannel: LocalImageChannel(),
      historyRepository: OperationHistoryRepository(database: database),
      recentFilesRepository: RecentFilesRepository(database: database),
    );
    Get.put(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const WatermarkView(),
      ),
    );
    await tester.pump();

    expect(find.text('Text Watermark'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(
      find.text(
        'Select a JPG, PNG, WebP, or BMP image to add a local text watermark.',
      ),
      findsOneWidget,
    );
    expect(find.text('Select One'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    controller.selectedImage.value = const LocalImageFile(
      path: 'watermark_preview.png',
      name: 'watermark_preview.png',
      sizeBytes: 1200,
      mimeType: 'image/png',
      width: 1200,
      height: 800,
    );
    controller.selectedImages.assignAll([controller.selectedImage.value!]);
    await tester.pump();

    expect(find.text('Watermark Text'), findsWidgets);
    expect(find.text('Bottom Right'), findsOneWidget);
    expect(find.text('White'), findsOneWidget);
    expect(find.text('Font Size: 36px'), findsOneWidget);
    expect(find.text('Opacity: 70%'), findsOneWidget);
    expect(find.text('Watermark Settings'), findsNothing);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片水印页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，验证空状态和选图后的紧凑覆盖式配置栏。
    final database = AppDatabase(NativeDatabase.memory());
    final controller = ImageWatermarkController(
      imageChannel: LocalImageChannel(),
      historyRepository: OperationHistoryRepository(database: database),
      recentFilesRepository: RecentFilesRepository(database: database),
    );
    Get.put(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: const ImageWatermarkView(),
      ),
    );
    await tester.pump();

    expect(find.text('Image Watermark'), findsOneWidget);
    expect(find.text('Select Base Image'), findsWidgets);
    expect(
      find.text('Select a base image to add an image watermark.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    controller.selectedImage.value = const LocalImageFile(
      path: 'image_watermark_preview.png',
      name: 'image_watermark_preview.png',
      sizeBytes: 1200,
      mimeType: 'image/png',
      width: 1200,
      height: 800,
    );
    controller.selectedImages.assignAll([controller.selectedImage.value!]);
    await tester.pump();

    expect(find.text('Select Watermark'), findsOneWidget);
    expect(find.text('Bottom Right'), findsOneWidget);
    expect(find.text('Opacity: 70%'), findsOneWidget);
    expect(find.text('Scale: 25%'), findsOneWidget);
    expect(find.text('Rotation: 0°'), findsOneWidget);
    expect(find.text('Watermark Settings'), findsNothing);
    final disabledExportButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('editor-export-action')),
    );
    expect(disabledExportButton.onPressed, isNull);

    controller.selectedWatermark.value = const LocalImageFile(
      path: 'watermark_logo.png',
      name: 'watermark_logo.png',
      sizeBytes: 320,
      mimeType: 'image/png',
      width: 128,
      height: 128,
    );
    await tester.pump();

    final enabledExportButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('editor-export-action')),
    );
    expect(enabledExportButton.onPressed, isNotNull);

    await database.close();
    Get.reset();
  });

  testWidgets('宫格自定义预览错误回调使用统一占位', (WidgetTester tester) async {
    // 直接执行自定义 Image.file 的错误回调，避免文件系统异步时序影响测试稳定性。
    final database = AppDatabase(NativeDatabase.memory());
    final controller = GridController(
      imageChannel: LocalImageChannel(),
      historyRepository: OperationHistoryRepository(database: database),
      recentFilesRepository: RecentFilesRepository(database: database),
    );
    controller.selectedImage.value = const LocalImageFile(
      path: 'missing-grid-image.png',
      name: 'missing-grid-image.png',
      sizeBytes: 512,
      mimeType: 'image/png',
      width: 800,
      height: 600,
    );
    Get.put(controller);

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

    final gridImageFinder = find.byType(Image);
    expect(gridImageFinder, findsOneWidget);
    final gridImage = tester.widget<Image>(gridImageFinder);
    expect(gridImage.errorBuilder, isNotNull);
    final errorPlaceholder = gridImage.errorBuilder!(
      gridImageFinder.evaluate().single,
      StateError('测试坏图'),
      StackTrace.current,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('zh', 'CN'),
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 240, height: 160, child: errorPlaceholder),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('Image failed to load'), findsOneWidget);
    expect(find.text('missing-grid-image.png'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文 PDF 工具页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证图片转 PDF 和 PDF 导出区域首屏文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      PdfController(
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
        home: const PdfView(),
      ),
    );
    await tester.pump();

    expect(find.text('PDF Tools'), findsOneWidget);
    expect(find.text('Select Images'), findsOneWidget);
    expect(
      find.text('Select 1 to 50 images. Each image becomes one PDF page.'),
      findsOneWidget,
    );
    expect(find.text('Select Batch'), findsOneWidget);
    expect(find.text('Page Settings'), findsOneWidget);
    expect(find.text('Portrait'), findsOneWidget);
    expect(find.text('Landscape'), findsOneWidget);
    expect(
      find.text(
        'Images are scaled proportionally and centered on the page with margins to avoid cropping.',
      ),
      findsOneWidget,
    );
    expect(find.text('Images to PDF'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文 GIF 工具页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证生成、拆帧和压缩区域首屏文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      GifController(
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
        home: const GifView(),
      ),
    );
    await tester.pump();

    expect(find.text('GIF Tools'), findsOneWidget);
    expect(find.text('Select Frame Images'), findsOneWidget);
    expect(
      find.text(
        'Select 2 to 30 images. The picker order becomes the GIF frame order.',
      ),
      findsOneWidget,
    );
    expect(find.text('Select Batch'), findsOneWidget);
    expect(find.text('Playback Speed'), findsOneWidget);
    expect(find.text('Frame Delay: 300 ms'), findsOneWidget);
    expect(
      find.text(
        'Smaller delays play faster. All frames are scaled to the first image size during export.',
      ),
      findsOneWidget,
    );
    expect(find.text('Create GIF'), findsOneWidget);

    await database.close();
    Get.reset();
  });
}

class _DelayedSettingsRepository extends AppSettingsRepository {
  _DelayedSettingsRepository({required super.database, required this.delay});

  final Duration delay;

  @override
  Future<String> getDefaultExportFormat() async {
    await Future<void>.delayed(delay);
    return super.getDefaultExportFormat();
  }

  @override
  Future<String> getDefaultSaveRule() async {
    await Future<void>.delayed(delay);
    return super.getDefaultSaveRule();
  }

  @override
  Future<String> getThemeMode() async {
    await Future<void>.delayed(delay);
    return super.getThemeMode();
  }

  @override
  Future<String> getLanguage() async {
    await Future<void>.delayed(delay);
    return super.getLanguage();
  }

  @override
  Future<String?> getDefaultExportDirectory() async {
    await Future<void>.delayed(delay);
    return super.getDefaultExportDirectory();
  }
}

Future<void> _closeRegisteredAppDatabase() async {
  // 根应用测试会通过 InitialBinding 延迟创建真实数据库；
  // 测试结束必须主动关闭并清理 GetX，避免后续内存数据库触发重复实例告警。
  if (Get.isRegistered<AppDatabase>()) {
    await Get.find<AppDatabase>().close();
  }
  Get.reset();
}
