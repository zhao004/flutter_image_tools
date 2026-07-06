import 'package:get/get.dart';

import '../../repositories/app_settings_repository.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';
import 'convert_controller.dart';

class ConvertBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConvertController>(
      () => ConvertController(
        imageChannel: Get.find<LocalImageChannel>(),
        historyRepository: Get.find<OperationHistoryRepository>(),
        settingsRepository: Get.find<AppSettingsRepository>(),
        recentFilesRepository: Get.find<RecentFilesRepository>(),
      ),
    );
  }
}
