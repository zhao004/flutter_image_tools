import 'package:get/get.dart';

import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';
import 'image_watermark_controller.dart';

class ImageWatermarkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ImageWatermarkController>(
      () => ImageWatermarkController(
        imageChannel: Get.find<LocalImageChannel>(),
        historyRepository: Get.find<OperationHistoryRepository>(),
        recentFilesRepository: Get.find<RecentFilesRepository>(),
      ),
    );
  }
}
