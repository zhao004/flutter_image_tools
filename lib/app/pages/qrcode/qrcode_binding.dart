import 'package:get/get.dart';

import '../../repositories/operation_history_repository.dart';
import 'qrcode_controller.dart';

class QrcodeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<QrcodeController>(
      () => QrcodeController(
        historyRepository: Get.find<OperationHistoryRepository>(),
      ),
    );
  }
}
