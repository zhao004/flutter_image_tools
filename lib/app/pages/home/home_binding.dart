import 'package:get/get.dart';

import '../../repositories/app_settings_repository.dart';
import '../../repositories/recent_files_repository.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(
        settingsRepository: Get.find<AppSettingsRepository>(),
        recentFilesRepository: Get.find<RecentFilesRepository>(),
      ),
    );
  }
}
