import 'package:get/get.dart';

import '../../repositories/operation_history_repository.dart';
import 'history_controller.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryController>(
      () =>
          HistoryController(repository: Get.find<OperationHistoryRepository>()),
    );
  }
}
