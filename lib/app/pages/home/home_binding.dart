import 'package:get/get.dart';

import '../../repositories/recent_files_repository.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(
        recentFilesRepository: Get.find<RecentFilesRepository>(),
      ),
    );
  }
}
