import 'package:get/get.dart';

import '../../database/database.dart';
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
  HomeController({required RecentFilesRepository recentFilesRepository})
    : _recentFilesRepository = recentFilesRepository;

  final RecentFilesRepository _recentFilesRepository;

  final query = ''.obs;
  final recentFiles = <RecentFile>[].obs;

  final tools = <HomeToolItem>[
    const HomeToolItem(
      titleKey: 'home.tool.compress.title',
      descriptionKey: 'home.tool.compress.description',
      icon: 'compress',
      availability: ToolAvailability.available,
      route: Routes.compress,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.batch.title',
      descriptionKey: 'home.tool.batch.description',
      icon: 'batch',
      availability: ToolAvailability.available,
      route: Routes.batch,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.history.title',
      descriptionKey: 'home.tool.history.description',
      icon: 'history',
      availability: ToolAvailability.available,
      route: Routes.history,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.settings.title',
      descriptionKey: 'home.tool.settings.description',
      icon: 'settings',
      availability: ToolAvailability.available,
      route: Routes.settings,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.crop.title',
      descriptionKey: 'home.tool.crop.description',
      icon: 'crop',
      availability: ToolAvailability.available,
      route: Routes.crop,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.merge.title',
      descriptionKey: 'home.tool.merge.description',
      icon: 'merge',
      availability: ToolAvailability.available,
      route: Routes.merge,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.resize.title',
      descriptionKey: 'home.tool.resize.description',
      icon: 'resize',
      availability: ToolAvailability.available,
      route: Routes.resize,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.flip.title',
      descriptionKey: 'home.tool.flip.description',
      icon: 'flip',
      availability: ToolAvailability.available,
      route: Routes.flip,
    ),
    const HomeToolItem(
      titleKey: 'home.tool.rotate.title',
      descriptionKey: 'home.tool.rotate.description',
      icon: 'rotate',
      availability: ToolAvailability.available,
      route: Routes.rotate,
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
      titleKey: 'home.tool.filter.title',
      descriptionKey: 'home.tool.filter.description',
      icon: 'filter',
      availability: ToolAvailability.available,
      route: Routes.filter,
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

  List<HomeToolItem> get recentTools => tools
      .where((tool) => tool.availability == ToolAvailability.available)
      .toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    loadRecentFiles();
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

  void openTool(HomeToolItem tool) {
    final route = tool.route;
    if (tool.availability != ToolAvailability.available || route == null) {
      Get.snackbar(
        'home.planned.title'.tr,
        'home.planned.message'.trParams({'tool': tool.title}),
      );
      return;
    }
    Get.toNamed(route);
  }
}
