import 'package:get/get.dart';

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
        recentFilesRepository: Get.find<RecentFilesRepository>(),
      ),
    );
  }
}
