import 'package:get/get.dart';

import '../../repositories/operation_history_repository.dart';
import '../../services/local_image_channel.dart';
import 'compress_controller.dart';

class CompressBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CompressController>(
      () => CompressController(
        imageChannel: Get.find<LocalImageChannel>(),
        historyRepository: Get.find<OperationHistoryRepository>(),
      ),
    );
  }
}
