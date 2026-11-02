import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../database/database.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../routes/app_pages.dart';

enum ToolAvailability { available, planned }

class HomeToolItem {
  const HomeToolItem({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.availability,
    this.route,
  });

  final String titleKey;
  final String descriptionKey;
  final String icon;
  final ToolAvailability availability;
  final String? route;

  String get title => titleKey.tr;

  String get description => descriptionKey.tr;
}

/// 首页状态控制器，负责维护工具入口、搜索和近期常用展示。
///
/// 设计意图：工具清单先集中在 Controller，后续可迁移到 Drift 收藏和
/// 最近使用记录；跳转前校验 route，避免未实现功能触发空路由异常。
class HomeController extends GetxController {
  HomeController({
    required AppSettingsRepository settingsRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _settingsRepository = settingsRepository,
       _recentFilesRepository = recentFilesRepository;

  final AppSettingsRepository _settingsRepository;
  final RecentFilesRepository _recentFilesRepository;

  final query = ''.obs;
  final recentFiles = <RecentFile>[].obs;
  final recentToolRoutes = <String>[].obs;
  final favoriteToolRoutes = <String>[].obs;

  final tools = <HomeToolItem>[
    const HomeToolItem(
      titleKey: 'home.tool.compress.title',
      descriptionKey: 'home.tool.compress.description',
      icon: 'compress',
      availability: ToolAvailability.available,
      route: Routes.compress,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.merge.title',
      descriptionKey: 'home.tool.merge.description',
      icon: 'merge',
      availability: ToolAvailability.available,
      route: Routes.merge,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.watermark.title',
      descriptionKey: 'home.tool.watermark.description',
      icon: 'watermark',
      availability: ToolAvailability.available,
      route: Routes.watermark,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.imageWatermark.title',
      descriptionKey: 'home.tool.imageWatermark.description',
      icon: 'imageWatermark',
      availability: ToolAvailability.available,
      route: Routes.imageWatermark,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.annotation.title',
      descriptionKey: 'home.tool.annotation.description',
      icon: 'annotation',
      availability: ToolAvailability.available,
      route: Routes.annotation,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.grid.title',
      descriptionKey: 'home.tool.grid.description',
      icon: 'grid',
      availability: ToolAvailability.available,
      route: Routes.grid,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.convert.title',
      descriptionKey: 'home.tool.convert.description',
      icon: 'convert',
      availability: ToolAvailability.available,
      route: Routes.convert,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.exif.title',
      descriptionKey: 'home.tool.exif.description',
      icon: 'exif',
      availability: ToolAvailability.available,
      route: Routes.exif,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.pdf.title',
      descriptionKey: 'home.tool.pdf.description',
      icon: 'pdf',
      availability: ToolAvailability.available,
      route: Routes.pdf,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.qrcode.title',
      descriptionKey: 'home.tool.qrcode.description',
      icon: 'qrcode',
      availability: ToolAvailability.available,
      route: Routes.qrcode,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.gif.title',
      descriptionKey: 'home.tool.gif.description',
      icon: 'gif',
      availability: ToolAvailability.available,
      route: Routes.gif,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.base64.title',
      descriptionKey: 'home.tool.base64.description',
      icon: 'base64',
      availability: ToolAvailability.available,
      route: Routes.base64,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.color.title',
      descriptionKey: 'home.tool.color.description',
      icon: 'color',
      availability: ToolAvailability.available,
      route: Routes.colorPicker,
    ),
  ];

  List<HomeToolItem> get filteredTools {
    final keyword = query.value.trim();
    if (keyword.isEmpty) {
      return tools;
    }
    final normalizedKeyword = keyword.toLowerCase();
    return tools
        .where(
          (tool) =>
              tool.title.toLowerCase().contains(normalizedKeyword) ||
              tool.description.toLowerCase().contains(normalizedKeyword),
        )
        .toList(growable: false);
  }

  List<HomeToolItem> get recentTools {
    final recent = recentToolRoutes
        .map(_toolForRoute)
        .whereType<HomeToolItem>()
        .where((tool) => tool.availability == ToolAvailability.available)
        .toList(growable: false);
    if (recent.isNotEmpty) {
      return recent;
    }
    return tools
        .where((tool) => tool.availability == ToolAvailability.available)
        .take(6)
        .toList(growable: false);
  }

  List<HomeToolItem> get favoriteTools => favoriteToolRoutes
      .map(_toolForRoute)
      .whereType<HomeToolItem>()
      .where((tool) => tool.availability == ToolAvailability.available)
      .toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    loadFavoriteTools();
    loadRecentTools();
    loadRecentFiles();
  }

  Future<void> loadFavoriteTools() async {
    try {
      final routes = await _settingsRepository.getFavoriteToolRoutes();
      favoriteToolRoutes.assignAll(
        routes.where((route) => _toolForRoute(route) != null),
      );
    } catch (_) {
      favoriteToolRoutes.clear();
    }
  }

  Future<void> loadRecentTools() async {
    try {
      final routes = await _settingsRepository.getRecentToolRoutes();
      recentToolRoutes.assignAll(
        routes.where((route) => _toolForRoute(route) != null),
      );
    } catch (_) {
      recentToolRoutes.clear();
    }
  }

  Future<void> loadRecentFiles() async {
    try {
      recentFiles.assignAll(await _recentFilesRepository.getRecentFiles());
    } catch (_) {
      recentFiles.clear();
    }
  }

  void updateQuery(String value) {
    query.value = value;
  }

  bool isFavoriteTool(HomeToolItem tool) {
    final route = tool.route;
    return route != null && favoriteToolRoutes.contains(route);
  }

  Future<void> toggleFavoriteTool(HomeToolItem tool) async {
    final route = tool.route;
    if (tool.availability != ToolAvailability.available || route == null) {
      return;
    }
    final nextRoutes = favoriteToolRoutes.contains(route)
        ? favoriteToolRoutes.where((item) => item != route).toList()
        : <String>[route, ...favoriteToolRoutes];
    final normalized = nextRoutes
        .take(AppSettingsRepository.maxFavoriteToolRoutes)
        .toList(growable: false);
    favoriteToolRoutes.assignAll(normalized);
    try {
      await _settingsRepository.setFavoriteToolRoutes(normalized);
    } catch (_) {
      // 收藏状态优先即时刷新，持久化失败不弹提示，避免频繁打断用户。
    }
  }

  Future<void> openSettings() async {
    final tool = _toolForRoute(Routes.settings);
    if (tool == null) {
      Get.toNamed(Routes.settings);
      return;
    }
    await openTool(tool);
  }

  Future<void> openTool(HomeToolItem tool) async {
    final route = tool.route;
    if (tool.availability != ToolAvailability.available || route == null) {
      showLatestSnackbar(
        'home.planned.title'.tr,
        'home.planned.message'.trParams({'tool': tool.title}),
      );
      return;
    }
    await _recordRecentTool(route);
    Get.toNamed(route);
  }

  Future<void> _recordRecentTool(String route) async {
    final nextRoutes = <String>[
      route,
      ...recentToolRoutes.where((item) => item != route),
    ].take(AppSettingsRepository.maxRecentToolRoutes).toList(growable: false);
    recentToolRoutes.assignAll(nextRoutes);
    try {
      await _settingsRepository.setRecentToolRoutes(nextRoutes);
    } catch (_) {
      // 最近工具是体验增强项，写入失败不阻断实际页面跳转。
    }
  }

  HomeToolItem? _toolForRoute(String route) {
    final normalized = route.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final tool in tools) {
      if (tool.route == normalized) {
        return tool;
      }
    }
    return null;
  }
}
