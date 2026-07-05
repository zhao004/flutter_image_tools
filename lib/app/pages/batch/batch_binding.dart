import 'package:get/get.dart';

import '../../repositories/app_settings_repository.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';
import 'batch_controller.dart';

class BatchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BatchController>(
      () => BatchController(
        imageChannel: Get.find<LocalImageChannel>(),
        historyRepository: Get.find<OperationHistoryRepository>(),
        settingsRepository: Get.find<AppSettingsRepository>(),
        recentFilesRepository: Get.find<RecentFilesRepository>(),
      ),
    );
  }
}
