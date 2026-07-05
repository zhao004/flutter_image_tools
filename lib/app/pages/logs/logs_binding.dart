import 'package:get/get.dart';

import '../../repositories/operation_logs_repository.dart';
import 'logs_controller.dart';

class LogsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LogsController>(
      () => LogsController(repository: Get.find<OperationLogsRepository>()),
    );
  }
}
