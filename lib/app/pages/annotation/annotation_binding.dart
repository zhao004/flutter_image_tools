import 'package:get/get.dart';

import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';
import 'annotation_controller.dart';

class AnnotationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AnnotationController>(
      () => AnnotationController(
        imageChannel: Get.find<LocalImageChannel>(),
        historyRepository: Get.find<OperationHistoryRepository>(),
        recentFilesRepository: Get.find<RecentFilesRepository>(),
      ),
    );
  }
}
