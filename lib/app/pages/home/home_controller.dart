import 'package:get/get.dart';

import '../../database/database.dart';
import '../../repositories/recent_files_repository.dart';
import '../../routes/app_pages.dart';

enum ToolAvailability { available, planned }

class HomeToolItem {
  const HomeToolItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.availability,
    this.route,
  });

  final String title;
  final String description;
  final String icon;
  final ToolAvailability availability;
  final String? route;
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
      title: '图片压缩',
      description: '按质量压缩本地图片',
      icon: 'compress',
      availability: ToolAvailability.available,
      route: Routes.compress,
    ),
    const HomeToolItem(
      title: '历史记录',
      description: '查看本机处理记录',
      icon: 'history',
      availability: ToolAvailability.available,
      route: Routes.history,
    ),
    const HomeToolItem(
      title: '设置',
      description: '导出、质量和主题偏好',
      icon: 'settings',
      availability: ToolAvailability.available,
      route: Routes.settings,
    ),
    const HomeToolItem(
      title: '图片裁剪',
      description: '自由比例和常用比例',
      icon: 'crop',
      availability: ToolAvailability.planned,
    ),
    const HomeToolItem(
      title: '图片拼接',
      description: '横向、纵向和网格拼接',
      icon: 'merge',
      availability: ToolAvailability.planned,
    ),
    const HomeToolItem(
      title: '尺寸调整',
      description: '按宽高或百分比缩放',
      icon: 'resize',
      availability: ToolAvailability.available,
      route: Routes.resize,
    ),
    const HomeToolItem(
      title: '图片翻转',
      description: '水平或垂直翻转',
      icon: 'flip',
      availability: ToolAvailability.available,
      route: Routes.flip,
    ),
    const HomeToolItem(
      title: '图片旋转',
      description: '90 度、180 度或任意角度',
      icon: 'rotate',
      availability: ToolAvailability.available,
      route: Routes.rotate,
    ),
    const HomeToolItem(
      title: '文字水印',
      description: '多行文字、透明度和位置',
      icon: 'watermark',
      availability: ToolAvailability.planned,
    ),
    const HomeToolItem(
      title: '格式转换',
      description: 'PNG、JPG、WebP、BMP',
      icon: 'convert',
      availability: ToolAvailability.planned,
    ),
    const HomeToolItem(
      title: 'PDF 工具',
      description: '图片转 PDF 与页面导出',
      icon: 'pdf',
      availability: ToolAvailability.planned,
    ),
    const HomeToolItem(
      title: '二维码',
      description: '生成和识别二维码',
      icon: 'qrcode',
      availability: ToolAvailability.planned,
    ),
    const HomeToolItem(
      title: 'Base64',
      description: '图片和文本互转',
      icon: 'base64',
      availability: ToolAvailability.planned,
    ),
  ];

  List<HomeToolItem> get filteredTools {
    final keyword = query.value.trim();
    if (keyword.isEmpty) {
      return tools;
    }
    return tools
        .where(
          (tool) =>
              tool.title.contains(keyword) ||
              tool.description.contains(keyword),
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
      Get.snackbar('功能规划中', '${tool.title} 将在后续版本中提供');
      return;
    }
    Get.toNamed(route);
  }
}
