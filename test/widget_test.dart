import 'package:drift/native.dart';
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
    expect(find.text('Save to Gallery'), findsWidgets);

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

  testWidgets('统一编辑器选图后显示五段式布局', (WidgetTester tester) async {
    // 直接验证通用骨架的导航、画布、标签、属性面板和底部动作栏，避免单测依赖真实图片解码。
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
          tabBar: const Text('Range'),
          toolbar: const Text('Property Panel'),
          bottomToolbar: const Text('Bottom Toolbar'),
          resultSummary: const Text('Result Summary'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Grid Split'), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-canvas')), findsOneWidget);
    expect(find.text('preview.png'), findsOneWidget);
    expect(find.text('Range'), findsOneWidget);
    expect(find.text('Property Panel'), findsOneWidget);
    expect(find.text('Bottom Toolbar'), findsOneWidget);
    expect(find.text('Result Summary'), findsOneWidget);
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
    expect(find.text('Stroke: 12 px'), findsNothing);

    controller.selectedImage.value = const LocalImageFile(
      path: 'annotation_preview.png',
      name: 'annotation_preview.png',
      sizeBytes: 1200,
      mimeType: 'image/png',
      width: 1200,
      height: 800,
    );
    await tester.pump();

    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Brush'), findsOneWidget);
    expect(find.text('Mosaic'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Rectangle'), findsOneWidget);
    expect(find.text('Circle'), findsOneWidget);
    expect(find.text('Arrow'), findsOneWidget);
    expect(find.text('annotation_preview.png'), findsNothing);
    expect(find.textContaining('1200 × 800'), findsNothing);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('Red'), findsNothing);
    expect(find.text('Stroke: 12 px'), findsNothing);

    controller.addShapeLayer(EditableLayerType.rectangle);
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    controller.setMode(AnnotationMode.brush);
    await tester.pump();

    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Stroke: 12 px'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);

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
    expect(find.text('Compression Quality'), findsOneWidget);
    expect(find.text('Current Quality: 80%'), findsOneWidget);
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
    expect(find.text('Export Format'), findsOneWidget);
    expect(find.text('JPG'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('Export Quality: 95%'), findsOneWidget);
    expect(find.text('JPG and WebP use the export quality.'), findsOneWidget);
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
        width: 800,
        height: 600,
      ),
    ]);
    await tester.pump();

    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Order'), findsOneWidget);
    expect(find.text('Horizontal'), findsOneWidget);
    expect(find.text('Vertical'), findsOneWidget);
    expect(find.text('Grid'), findsNothing);
    expect(find.text('Long Image'), findsNothing);
    expect(find.text('Image Spacing: 8px'), findsOneWidget);

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文文字水印页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证统一编辑器选图空状态文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      WatermarkController(
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

    await database.close();
    Get.reset();
  });

  testWidgets('显示英文图片水印页面', (WidgetTester tester) async {
    // 直接注入控制器依赖，仅验证统一编辑器底图选图空状态文案国际化。
    final database = AppDatabase(NativeDatabase.memory());
    Get.put(
      ImageWatermarkController(
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
    expect(find.text('Save to Gallery'), findsWidgets);

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
